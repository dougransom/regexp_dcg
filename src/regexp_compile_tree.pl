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
    compile_node(B, C0, C1, Cont, NodeB),
    compile_node(A, C1, CF, NodeB, Node).
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
    C1 is C0 + 1,
    compile_node(Inner, C1, CF, cap_close(C0, Cont), NodeInner).

compile_node(named_capture(Name, Inner), C0, CF, Cont, named_open(Name, C0, NodeInner)) :-
    !,
    C1 is C0 + 1,
    compile_node(Inner, C1, CF, named_close(Name, C0, Cont), NodeInner).

compile_node(postfix(Expr, star), C0, CF, Cont, star(SubNode, Cont)) :-
    !,
    compile_node(Expr, C0, CF, end, SubNode).

compile_node(postfix(Expr, plus), C0, CF, Cont, Node) :-
    !,
    compile_node(Expr, C0, C1, star(SubNode, Cont), Node),
    compile_node(Expr, C1, CF, end, SubNode).

compile_node(postfix(Expr, question), C0, CF, Cont, opt(SubNode, Cont)) :-
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
    M =< N,
    RestCount is N - M,
    compile_optionals(RestCount, Expr, C0, C1, Cont, NodeOpt),
    compile_exact_n(M, Expr, C1, CF, NodeOpt, Node).

compile_node(dot, C, C, Cont, sym(dot, Cont, stp)) :- !.
compile_node(escaped(Char), C, C, Cont, sym(char(Char), Cont, stp)) :- !.
compile_node(anchor(bol), C, C, Cont, sym(bol, Cont, stp)) :- !.
compile_node(anchor(eol), C, C, Cont, sym(eol, Cont, stp)) :- !.
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
compile_node(flags(_), C, C, Cont, Cont) :- !.
compile_node(flags(_, Sub), C0, CF, Cont, Node) :-
    !,
    compile_node(Sub, C0, CF, Cont, Node).

compile_seq([], C, C, Cont, Cont).
compile_seq([H|T], C0, CF, Cont, Node) :-
    compile_seq(T, C0, C1, Cont, RestNode),
    compile_node(H, C1, CF, RestNode, Node).

compile_exact_n(0, _, C, C, Cont, Cont) :- !.
compile_exact_n(N, Expr, C0, CF, Cont, Node) :-
    N > 0,
    N1 is N - 1,
    compile_exact_n(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(Expr, C1, CF, RestNode, Node).

compile_optionals(0, _, C, C, Cont, Cont) :- !.
compile_optionals(N, Expr, C0, CF, Cont, Node) :-
    N > 0,
    N1 is N - 1,
    compile_optionals(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(postfix(Expr, question), C1, CF, RestNode, Node).

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

regex_tree_run(Chars, opt(SubNode, Cont), S0, SF, Rest) :-
    (   regex_tree_run(Chars, SubNode, S0, SF, Rest)
    ;   regex_tree_run(Chars, Cont, S0, SF, Rest)
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

% Empty input handling: check end-of-line anchor or fail fallback
regex_tree_run([], sym(Cond, Succ, Fail), S0, SF, Rest) :-
    if_(match_cond_empty(Cond),
        regex_tree_run([], Succ, S0, SF, Rest),
        regex_tree_run([], Fail, S0, SF, Rest)).

% Non-empty input matching using if_/3 reified condition
regex_tree_run([H|T], sym(Cond, Succ, Fail), S0, SF, Rest) :-
    if_(match_cond(Cond, H),
        regex_tree_run(T, Succ, S0, SF, Rest),
        regex_tree_run([H|T], Fail, S0, SF, Rest)).

%% match_cond_empty(+Cond, -Truth)
%
% Reified check for empty string matching (e.g. eol anchor).
match_cond_empty(eol, true) :- !.
match_cond_empty(_, false).

%% match_cond(+Cond, +Char, -Truth)
%
% Reified condition matcher returning `true` or `false` in `Truth`.
match_cond(char(C), H, Truth) :-
    =(C, H, Truth).

match_cond(dot, H, Truth) :-
    if_(H = '\n', Truth = false, Truth = true).

match_cond(bol, _H, true).
match_cond(eol, _H, false).

match_cond(builtin(Code), H, Truth) :-
    match_builtin_class(Code, H, Truth).

match_cond(class(Items), H, Truth) :-
    match_class_items(Items, H, Truth).

match_cond(neg_class(Items), H, Truth) :-
    match_class_items(Items, H, T0),
    if_(T0 = true, Truth = false, Truth = true).

%% match_class_items(+Items, +Char, -Truth)
match_class_items([], _H, false).
match_class_items([Item|Items], H, Truth) :-
    match_class_item(Item, H, T0),
    if_(T0 = true,
        Truth = true,
        match_class_items(Items, H, Truth)).

char_le_t(A, B, true) :- A @=< B, !.
char_le_t(_, _, false).

char_ge_t(A, B, true) :- A @>= B, !.
char_ge_t(_, _, false).

char_range_t(Min, Max, Char, Truth) :-
    if_(char_ge_t(Char, Min),
        char_le_t(Char, Max, Truth),
        Truth = false).

match_class_item(range(Min, Max), H, Truth) :-
    char_range_t(Min, Max, H, Truth).
match_class_item(char(C), H, Truth) :-
    =(C, H, Truth).
match_class_item(lit([C]), H, Truth) :-
    =(C, H, Truth).
match_class_item(lit(Cs), H, Truth) :-
    match_char_in_list(Cs, H, Truth).
match_class_item(builtin(Code), H, Truth) :-
    match_builtin_class(Code, H, Truth).
match_class_item(posix(Name), H, Truth) :-
    match_posix_class(Name, H, Truth).

match_char_in_list([], _H, false).
match_char_in_list([C|Cs], H, Truth) :-
    if_(C = H,
        Truth = true,
        match_char_in_list(Cs, H, Truth)).

match_builtin_class(digit, H, Truth) :-
    char_range_t('0', '9', H, Truth).
match_builtin_class('d', H, Truth) :- match_builtin_class(digit, H, Truth).

match_builtin_class(not_digit, H, Truth) :-
    match_builtin_class(digit, H, T0),
    if_(T0 = true, Truth = false, Truth = true).
match_builtin_class('D', H, Truth) :- match_builtin_class(not_digit, H, Truth).

match_builtin_class(word, H, Truth) :-
    if_(char_range_t('a', 'z', H), Truth = true,
    if_(char_range_t('A', 'Z', H), Truth = true,
    if_(char_range_t('0', '9', H), Truth = true,
    =(H, '_', Truth)))).
match_builtin_class('w', H, Truth) :- match_builtin_class(word, H, Truth).

match_builtin_class(not_word, H, Truth) :-
    match_builtin_class(word, H, T0),
    if_(T0 = true, Truth = false, Truth = true).
match_builtin_class('W', H, Truth) :- match_builtin_class(not_word, H, Truth).

match_builtin_class(space, H, Truth) :-
    if_(H = ' ', Truth = true,
    if_(H = '\t', Truth = true,
    if_(H = '\n', Truth = true,
    if_(H = '\r', Truth = true,
    if_(H = '\f', Truth = true,
    if_(H = '\v', Truth = true, Truth = false)))))).
match_builtin_class('s', H, Truth) :- match_builtin_class(space, H, Truth).

match_builtin_class(not_space, H, Truth) :-
    match_builtin_class(space, H, T0),
    if_(T0 = true, Truth = false, Truth = true).
match_builtin_class('S', H, Truth) :- match_builtin_class(not_space, H, Truth).

match_posix_class(alnum, H, Truth) :- match_builtin_class(word, H, Truth).
match_posix_class(alpha, H, Truth) :-
    if_(char_range_t('a', 'z', H), Truth = true,
    char_range_t('A', 'Z', H, Truth)).
match_posix_class(digit, H, Truth) :- match_builtin_class(digit, H, Truth).
match_posix_class(lower, H, Truth) :- char_range_t('a', 'z', H, Truth).
match_posix_class(upper, H, Truth) :- char_range_t('A', 'Z', H, Truth).
match_posix_class(space, H, Truth) :- match_builtin_class(space, H, Truth).
match_posix_class(xdigit, H, Truth) :-
    if_(char_range_t('0', '9', H), Truth = true,
    if_(char_range_t('a', 'f', H), Truth = true,
    char_range_t('A', 'F', H, Truth))).

/* Helper state modifiers for group capture tracking */

update_cap_open(state(Full, Groups, Named), Idx, RemainingChars, state(Full, NewGroups, Named)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups).

update_cap_close(state(Full, Groups, Named), Idx, RemainingChars, state(Full, NewGroups, Named)) :-
    set_group_end(Full, Groups, Idx, RemainingChars, NewGroups).

update_named_open(state(Full, Groups, Named), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups),
    set_named_start(Named, Name, Idx, RemainingChars, NewNamed).

update_named_close(state(Full, Groups, Named), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed)) :-
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
    N > 0,
    N1 is N - 1,
    replace_nth(T, N1, Val, R).

extract_substring(Full, StartChars, EndChars, Substr) :-
    length(Full, LFull),
    length(StartChars, LStart),
    length(EndChars, LEnd),
    Skip is LFull - LStart,
    Take is LStart - LEnd,
    drop_n(Skip, Full, Rest),
    take_n(Take, Rest, Substr).

drop_n(0, L, L) :- !.
drop_n(N, [_|T], R) :- N > 0, N1 is N - 1, drop_n(N1, T, R).

take_n(0, _, []) :- !.
take_n(N, [H|T], [H|R]) :- N > 0, N1 is N - 1, take_n(N1, T, R).

is_bol(state(Full, _, _), Chars) :-
    (   Full == Chars ->
        true
    ;   length(Full, LFull),
        length(Chars, LChars),
        Skip is LFull - LChars - 1,
        Skip >= 0,
        nth0(Skip, Full, '\n')
    ).

is_eol([]) :- !.
is_eol(['\n'|_]).
