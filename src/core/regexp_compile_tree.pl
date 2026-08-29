/**
  Provides rational tree automaton compilation and pure if_/3 matching for regular expressions.

  This module compiles AST terms into rational tree automaton nodes represented as
  `sym(Condition, SuccState, FailState)`, `alt(NodeA, NodeB)`, `star(SubNode, Cont)`, `opt(SubNode, Cont)`,
  `end`, `stp`, and capture nodes.

  This was built by Antigravity with instructions to base on the https://github.com/mthom/scryer-prolog/discussions/2758
  
*/
:- module(regexp_compile_tree, [
    compile_ast_tree/3,
    regex_tree_run/5,
    match_cond/3,
    match_cond_empty/2
]).

:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).
:- use_module(library(dif)).
:- use_module(library(clpz)).
:- use_module(regexp_common, [
    match_builtin_t/3,
    char_range_t/4,
    parse_flags/2,
    char_lower/2,
    char_equal_ci/2,
    char_equal_ci_t/3,
    to_chars/2
]).

%% compile_ast_tree(+AST, -Automaton, -GroupCount)
%
% Compiles regex AST into a tree automaton `Automaton` and counts captured groups.
compile_ast_tree(AST, Automaton, GroupCount) :-
    compile_node(AST, 0, GroupCount, end, Automaton).

%% compile_node(+AST, +C0, -CF, +Cont, -Node)
%
% Compiles an AST node into an automaton node with continuation `Cont`.
compile_node(lit([]), C, C, Cont, Cont) :- !.
compile_node(lit([Char]), C, C, Cont, sym(char(Char), Cont, stp)) :- !.
compile_node(lit([C1, C2 | Cs]), C, C, Cont, Node) :-
    !,
    compile_node(lit([C2 | Cs]), C, C, Cont, RestNode),
    Node = sym(char(C1), RestNode, stp).

compile_node(concat(A, B), C0, CF, Cont, Node) :-
    !,
    compile_node(A, C0, C1, NodeB, Node),
    compile_node(B, C1, CF, Cont, NodeB).
compile_node(concat(List), C0, CF, Cont, Node) :-
    !,
    compile_seq(List, C0, CF, Cont, Node).

compile_node(or(A, B), C0, CF, Cont, alt(NodeA, NodeB)) :-
    !,
    compile_node(A, C0, C1, Cont, NodeA),
    compile_node(B, C1, CF, Cont, NodeB).

compile_node(group(Inner), C0, CF, Cont, Node) :-
    !,
    compile_node(Inner, C0, CF, Cont, Node).

compile_node(capture(Inner), C0, CF, Cont, cap_open(C0, NodeInner)) :-
    !,
    C1 #= C0 + 1,
    compile_node(Inner, C1, CF, cap_close(C0, Cont), NodeInner).

compile_node(named_capture(Name, Inner), C0, CF, Cont, named_open(Name, C0, NodeInner)) :-
    !,
    C1 #= C0 + 1,
    compile_node(Inner, C1, CF, named_close(Name, C0, Cont), NodeInner).

compile_node(postfix(Expr, star), C0, CF, Cont, star(SubNode, Cont)) :-
    !,
    compile_node(Expr, C0, CF, end, SubNode).

compile_node(postfix(Expr, lazy(star)), C0, CF, Cont, lazy_star(SubNode, Cont)) :-
    !,
    compile_node(Expr, C0, CF, end, SubNode).

compile_node(postfix(Expr, plus), C0, CF, Cont, Node) :-
    !,
    compile_node(Expr, C0, C1, star(SubNode, Cont), Node),
    compile_node(Expr, C1, CF, end, SubNode).

compile_node(postfix(Expr, lazy(plus)), C0, CF, Cont, Node) :-
    !,
    compile_node(Expr, C0, C1, lazy_star(SubNode, Cont), Node),
    compile_node(Expr, C1, CF, end, SubNode).

compile_node(postfix(Expr, question), C0, CF, Cont, opt(SubNode, Cont)) :-
    !,
    compile_node(Expr, C0, CF, Cont, SubNode).

compile_node(postfix(Expr, lazy(question)), C0, CF, Cont, lazy_opt(SubNode, Cont)) :-
    !,
    compile_node(Expr, C0, CF, Cont, SubNode).

compile_node(quant(Expr, mn(M, M)), C0, CF, Cont, Node) :-
    !,
    compile_exact_n(M, Expr, C0, CF, Cont, Node).
compile_node(quant(Expr, mn(0, inf)), C0, CF, Cont, Node) :-
    !,
    compile_node(postfix(Expr, star), C0, CF, Cont, Node).
compile_node(quant(Expr, mn(M, inf)), C0, CF, Cont, Node) :-
    !,
    compile_node(postfix(Expr, star), C0, C1, Cont, NodeStar),
    compile_exact_n(M, Expr, C1, CF, NodeStar, Node).
compile_node(quant(Expr, mn(M, N)), C0, CF, Cont, Node) :-
    !,
    M #=< N,
    RestCount #= N - M,
    compile_optionals(RestCount, Expr, C0, C1, Cont, NodeOpt),
    compile_exact_n(M, Expr, C1, CF, NodeOpt, Node).

compile_node(quant(Expr, lazy(mn(M, M))), C0, CF, Cont, Node) :-
    !,
    compile_exact_n(M, Expr, C0, CF, Cont, Node).
compile_node(quant(Expr, lazy(mn(0, inf))), C0, CF, Cont, Node) :-
    !,
    compile_node(postfix(Expr, lazy(star)), C0, CF, Cont, Node).
compile_node(quant(Expr, lazy(mn(M, inf))), C0, CF, Cont, Node) :-
    !,
    compile_node(postfix(Expr, lazy(star)), C0, C1, Cont, NodeStar),
    compile_exact_n(M, Expr, C1, CF, NodeStar, Node).
compile_node(quant(Expr, lazy(mn(M, N))), C0, CF, Cont, Node) :-
    !,
    M #=< N,
    RestCount #= N - M,
    compile_lazy_optionals(RestCount, Expr, C0, C1, Cont, NodeOpt),
    compile_exact_n(M, Expr, C1, CF, NodeOpt, Node).

compile_node(dot, C, C, Cont, sym(dot, Cont, stp)) :- !.
compile_node(escaped(Char), C, C, Cont, Node) :-
    !,
    (   char_range_t('1', '9', Char, true) ->
        char_code(Char, Code),
        Idx #= Code - 49,
        Node = backref(Idx, Cont)
    ;   Node = sym(char(Char), Cont, stp)
    ).
compile_node(anchor(bol), C, C, Cont, sym(bol, Cont, stp)) :- !.
compile_node(anchor(eol), C, C, Cont, sym(eol, Cont, stp)) :- !.
compile_node(boundary, C, C, Cont, sym(boundary, Cont, stp)) :- !.
compile_node(boundary(word), C, C, Cont, sym(boundary, Cont, stp)) :- !.
compile_node(not_boundary, C, C, Cont, sym(not_boundary, Cont, stp)) :- !.
compile_node(boundary(not_word), C, C, Cont, sym(not_boundary, Cont, stp)) :- !.
compile_node(backref(Idx), C, C, Cont, backref(Idx, Cont)) :- !.
compile_node(builtin(Class), C, C, Cont, sym(builtin(Class), Cont, stp)) :- !.
compile_node(class(neg(Items)), C, C, Cont, sym(neg_class(Items), Cont, stp)) :- !.
compile_node(class(Items), C, C, Cont, sym(class(Items), Cont, stp)) :- !.
compile_node(neg_class(Items), C, C, Cont, sym(neg_class(Items), Cont, stp)) :- !.
compile_node(lookahead(Sub), C0, CF, Cont, lookahead(SubNode, Cont, stp)) :-
    !,
    compile_node(Sub, C0, CF, end, SubNode).
compile_node(neg_lookahead(Sub), C0, CF, Cont, neg_lookahead(SubNode, Cont, stp)) :-
    !,
    compile_node(Sub, C0, CF, end, SubNode).
compile_node(flags(Flags), C, C, Cont, set_flags(Flags, Cont)) :- !.
compile_node(flags(Flags, Sub), C0, CF, Cont, scoped_flags(Flags, SubNode, Cont)) :-
    !,
    compile_node(Sub, C0, CF, Cont, SubNode).

compile_seq([], C, C, Cont, Cont).
compile_seq([H|T], C0, CF, Cont, Node) :-
    compile_node(H, C0, C1, RestNode, Node),
    compile_seq(T, C1, CF, Cont, RestNode).

compile_exact_n(0, _, C, C, Cont, Cont) :- !.
compile_exact_n(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_exact_n(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(Expr, C1, CF, RestNode, Node).

compile_optionals(0, _, C, C, Cont, Cont) :- !.
compile_optionals(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_optionals(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(postfix(Expr, question), C1, CF, RestNode, Node).

compile_lazy_optionals(0, _, C, C, Cont, Cont) :- !.
compile_lazy_optionals(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_lazy_optionals(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(postfix(Expr, lazy(question)), C1, CF, RestNode, Node).

%% regex_tree_run(+Chars, +Automaton, +State0, -StateF, -RestChars)
%
% Runs the automaton on `Chars` starting at state `Automaton`.
regex_tree_run(Chars, end, State, State, Chars).

regex_tree_run(_Chars, stp, _, _, _) :- fail.

regex_tree_run(Chars, alt(NodeA, NodeB), S0, SF, Rest) :-
    (   regex_tree_run(Chars, NodeA, S0, SF, Rest)
    ;   regex_tree_run(Chars, NodeB, S0, SF, Rest)
    ).

regex_tree_run(Chars, star(SubNode, Cont), S0, SF, Rest) :-
    (   regex_tree_run(Chars, SubNode, S0, S1, Rest1),
        dif(Rest1, Chars),
        regex_tree_run(Rest1, star(SubNode, Cont), S1, SF, Rest)
    ;   regex_tree_run(Chars, Cont, S0, SF, Rest)
    ).

regex_tree_run(Chars, lazy_star(SubNode, Cont), S0, SF, Rest) :-
    (   regex_tree_run(Chars, Cont, S0, SF, Rest)
    ;   regex_tree_run(Chars, SubNode, S0, S1, Rest1),
        dif(Rest1, Chars),
        regex_tree_run(Rest1, lazy_star(SubNode, Cont), S1, SF, Rest)
    ).

regex_tree_run(Chars, opt(SubNode, Cont), S0, SF, Rest) :-
    (   regex_tree_run(Chars, SubNode, S0, SF, Rest)
    ;   regex_tree_run(Chars, Cont, S0, SF, Rest)
    ).

regex_tree_run(Chars, lazy_opt(SubNode, Cont), S0, SF, Rest) :-
    (   regex_tree_run(Chars, Cont, S0, SF, Rest)
    ;   regex_tree_run(Chars, SubNode, S0, SF, Rest)
    ).

regex_tree_run(Chars, cap_open(Idx, Next), S0, SF, Rest) :-
    update_cap_open(S0, Idx, Chars, S1),
    regex_tree_run(Chars, Next, S1, SF, Rest).

regex_tree_run(Chars, cap_close(Idx, Next), S0, SF, Rest) :-
    update_cap_close(S0, Idx, Chars, S1),
    regex_tree_run(Chars, Next, S1, SF, Rest).

regex_tree_run(Chars, named_open(Name, Idx, Next), S0, SF, Rest) :-
    update_named_open(S0, Name, Idx, Chars, S1),
    regex_tree_run(Chars, Next, S1, SF, Rest).

regex_tree_run(Chars, named_close(Name, Idx, Next), S0, SF, Rest) :-
    update_named_close(S0, Name, Idx, Chars, S1),
    regex_tree_run(Chars, Next, S1, SF, Rest).

regex_tree_run(Chars, lookahead(SubNode, Next, Fail), S0, SF, Rest) :-
    (   regex_tree_run(Chars, SubNode, S0, _, _) ->
        regex_tree_run(Chars, Next, S0, SF, Rest)
    ;   regex_tree_run(Chars, Fail, S0, SF, Rest)
    ).

regex_tree_run(Chars, neg_lookahead(SubNode, Next, Fail), S0, SF, Rest) :-
    (   regex_tree_run(Chars, SubNode, S0, _, _) ->
        regex_tree_run(Chars, Fail, S0, SF, Rest)
    ;   regex_tree_run(Chars, Next, S0, SF, Rest)
    ).

regex_tree_run(Chars, set_flags(Flags, Next), S0, SF, Rest) :-
    S0 = state(Full, Groups, Named, OldFlags),
    parse_flags(Flags, NewFlags),
    append(NewFlags, OldFlags, CombinedFlags),
    S1 = state(Full, Groups, Named, CombinedFlags),
    regex_tree_run(Chars, Next, S1, SF, Rest).

regex_tree_run(Chars, scoped_flags(Flags, SubNode, Next), S0, SF, Rest) :-
    S0 = state(Full, Groups, Named, OldFlags),
    parse_flags(Flags, NewFlags),
    append(NewFlags, OldFlags, CombinedFlags),
    S1 = state(Full, Groups, Named, CombinedFlags),
    regex_tree_run(Chars, SubNode, S1, S2, Rest1),
    S2 = state(Full2, Groups2, Named2, _),
    SFinal = state(Full2, Groups2, Named2, OldFlags),
    regex_tree_run(Rest1, Next, SFinal, SF, Rest).

regex_tree_run(Chars, backref(Idx, Next), S0, SF, Rest) :-
    S0 = state(_, Groups, _, _),
    (   nth0(Idx, Groups, Captured),
        chars_si(Captured),
        append(Captured, RestChars, Chars) ->
        regex_tree_run(RestChars, Next, S0, SF, Rest)
    ;   fail
    ).

regex_tree_run(Chars, sym(bol, Succ, Fail), S0, SF, Rest) :-
    !,
    (   is_bol(S0, Chars) ->
        regex_tree_run(Chars, Succ, S0, SF, Rest)
    ;   regex_tree_run(Chars, Fail, S0, SF, Rest)
    ).

regex_tree_run(Chars, sym(eol, Succ, Fail), S0, SF, Rest) :-
    !,
    (   is_eol(Chars) ->
        regex_tree_run(Chars, Succ, S0, SF, Rest)
    ;   regex_tree_run(Chars, Fail, S0, SF, Rest)
    ).

regex_tree_run(Chars, sym(boundary, Succ, Fail), S0, SF, Rest) :-
    !,
    (   is_boundary(S0, Chars) ->
        regex_tree_run(Chars, Succ, S0, SF, Rest)
    ;   regex_tree_run(Chars, Fail, S0, SF, Rest)
    ).

regex_tree_run(Chars, sym(not_boundary, Succ, Fail), S0, SF, Rest) :-
    !,
    (   \+ is_boundary(S0, Chars) ->
        regex_tree_run(Chars, Succ, S0, SF, Rest)
    ;   regex_tree_run(Chars, Fail, S0, SF, Rest)
    ).

% Empty input handling: check end-of-line anchor or fail fallback
regex_tree_run([], sym(Cond, Succ, Fail), S0, SF, Rest) :-
    if_(match_cond_empty(Cond),
        regex_tree_run([], Succ, S0, SF, Rest),
        regex_tree_run([], Fail, S0, SF, Rest)).

% Non-empty input matching using if_/3 reified condition
regex_tree_run([H|T], sym(Cond, Succ, Fail), S0, SF, Rest) :-
    S0 = state(_, _, _, Flags),
    if_(match_cond_flags(Cond, H, Flags),
        regex_tree_run(T, Succ, S0, SF, Rest),
        regex_tree_run([H|T], Fail, S0, SF, Rest)).

%% match_cond_empty(+Cond, -Truth)
match_cond_empty(eol, true) :- !.
match_cond_empty(_, false).

%% match_cond_flags(+Cond, +Char, +Flags, -Truth)
match_cond_flags(Cond, H, Flags, Truth) :-
    (   member(case_insensitive, Flags) ->
        match_cond_ci(Cond, H, Truth)
    ;   match_cond(Cond, H, Truth)
    ).

%% match_cond(+Cond, +Char, -Truth)
match_cond(char(C), H, Truth) :-
    =(C, H, Truth).

match_cond(dot, H, Truth) :-
    if_(H = '\n', Truth = false, Truth = true).

match_cond(bol, _H, true).
match_cond(eol, _H, false).
match_cond(boundary, _H, true).
match_cond(not_boundary, _H, true).

match_cond(builtin(Code), H, Truth) :-
    match_builtin_t(Code, H, Truth).

match_cond(class(Items), H, Truth) :-
    match_class_items(Items, H, Truth).

match_cond(neg_class(Items), H, Truth) :-
    match_class_items(Items, H, T0),
    if_(T0 = true, Truth = false, Truth = true).

%% match_cond_ci(+Cond, +Char, -Truth)
match_cond_ci(char(C), H, Truth) :-
    char_equal_ci_t(C, H, Truth).
match_cond_ci(class(Items), H, Truth) :-
    match_class_items_ci(Items, H, Truth).
match_cond_ci(neg_class(Items), H, Truth) :-
    match_class_items_ci(Items, H, T0),
    if_(T0 = true, Truth = false, Truth = true).
match_cond_ci(Cond, H, Truth) :-
    match_cond(Cond, H, Truth).

match_class_items_ci([], _H, false).
match_class_items_ci([Item|Items], H, Truth) :-
    match_class_item_ci(Item, H, T0),
    if_(T0 = true,
        Truth = true,
        match_class_items_ci(Items, H, Truth)).

match_class_item_ci(char(C), H, Truth) :-
    char_equal_ci_t(C, H, Truth).
match_class_item_ci(range(Min, Max), H, Truth) :-
    char_lower(Min, LowerA),
    char_lower(Max, LowerB),
    char_lower(H, LowerC),
    char_range_t(LowerA, LowerB, LowerC, Truth).
match_class_item_ci(Item, H, Truth) :-
    match_class_item(Item, H, Truth).


/* Standard match_class_items and helpers */
match_class_items([], _H, false).
match_class_items([Item|Items], H, Truth) :-
    match_class_item(Item, H, T0),
    if_(T0 = true,
        Truth = true,
        match_class_items(Items, H, Truth)).

match_class_item(range(Min, Max), H, Truth) :-
    char_range_t(Min, Max, H, Truth).
match_class_item(char(C), H, Truth) :-
    =(C, H, Truth).
match_class_item(lit([C]), H, Truth) :-
    =(C, H, Truth).
match_class_item(lit(Cs), H, Truth) :-
    match_char_in_list(Cs, H, Truth).
match_class_item(builtin(Code), H, Truth) :-
    match_builtin_t(Code, H, Truth).
match_class_item(posix(Name), H, Truth) :-
    match_builtin_t(Name, H, Truth).

match_char_in_list([], _H, false).
match_char_in_list([C|Cs], H, Truth) :-
    if_(C = H,
        Truth = true,
        match_char_in_list(Cs, H, Truth)).

/* Helper state modifiers for group capture tracking */

update_cap_open(state(Full, Groups, Named, Flags), Idx, RemainingChars, state(Full, NewGroups, Named, Flags)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups).

update_cap_close(state(Full, Groups, Named, Flags), Idx, RemainingChars, state(Full, NewGroups, Named, Flags)) :-
    set_group_end(Full, Groups, Idx, RemainingChars, NewGroups).

update_named_open(state(Full, Groups, Named, Flags), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed, Flags)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups),
    set_named_start(Named, Name, Idx, RemainingChars, NewNamed).

update_named_close(state(Full, Groups, Named, Flags), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed, Flags)) :-
    set_group_end(Full, Groups, Idx, RemainingChars, NewGroups),
    set_named_end(Full, Named, Name, Idx, RemainingChars, NewNamed).

set_group_start(Groups, Idx, RemainingChars, NewGroups) :-
    (   nth0(Idx, Groups, capture(RemainingChars, _)) ->
        NewGroups = Groups
    ;   replace_nth(Groups, Idx, capture(RemainingChars, _), NewGroups)
    ).

set_group_end(Full, Groups, Idx, RemainingChars, NewGroups) :-
    (   nth0(Idx, Groups, capture(StartChars, _)) ->
        extract_substring(Full, StartChars, RemainingChars, Substr),
        replace_nth(Groups, Idx, Substr, NewGroups)
    ;   NewGroups = Groups
    ).

set_named_start(Named, Name, _, RemainingChars, [Name-capture(RemainingChars, _)|Named1]) :-
    delete_key(Named, Name, Named1).

set_named_end(Full, Named, Name, _, RemainingChars, [Name-Substr|Named1]) :-
    (   member(Name-capture(StartChars, _), Named) ->
        extract_substring(Full, StartChars, RemainingChars, Substr),
        delete_key(Named, Name, Named1)
    ;   Named1 = Named
    ).

delete_key([], _, []).
delete_key([K-_|T], K, T1) :- !, delete_key(T, K, T1).
delete_key([H|T], K, [H|T1]) :- delete_key(T, K, T1).

replace_nth([], _, _, []).
replace_nth([_|T], 0, Val, [Val|T]) :- !.
replace_nth([H|T], N, Val, [H|R]) :-
    N #> 0,
    N1 #= N - 1,
    replace_nth(T, N1, Val, R).

extract_substring(Full, StartChars, EndChars, Substr) :-
    length(Full, LFull),
    length(StartChars, LStart),
    length(EndChars, LEnd),
    Skip #= LFull - LStart,
    Take #= LStart - LEnd,
    drop_n(Skip, Full, Rest),
    take_n(Take, Rest, Substr).

drop_n(0, L, L) :- !.
drop_n(N, [_|T], R) :- N #> 0, N1 #= N - 1, drop_n(N1, T, R).

take_n(0, _, []) :- !.
take_n(N, [H|T], [H|R]) :- N #> 0, N1 #= N - 1, take_n(N1, T, R).

is_bol(state(Full, _, _, _), Chars) :-
    (   Full == Chars ->
        true
    ;   length(Full, LFull),
        length(Chars, LChars),
        Skip #= LFull - LChars - 1,
        Skip #>= 0,
        nth0(Skip, Full, '\n')
    ).

is_eol([]) :- !.
is_eol(['\n'|_]).

is_boundary(state(Full, _, _, _), Chars) :-
    (   Full == Chars ->
        Chars = [H|_],
        is_word_char(H)
    ;   Chars == [] ->
        length(Full, LFull),
        Skip #= LFull - 1,
        Skip #>= 0,
        nth0(Skip, Full, Prev),
        is_word_char(Prev)
    ;   length(Full, LFull),
        length(Chars, LChars),
        Skip #= LFull - LChars - 1,
        Skip #>= 0,
        nth0(Skip, Full, Prev),
        Chars = [Curr|_],
        (   is_word_char(Prev), \+ is_word_char(Curr)
        ;   \+ is_word_char(Prev), is_word_char(Curr)
        )
    ).

is_word_char(C) :-
    nonvar(C),
    match_builtin_t(word, C, true).
