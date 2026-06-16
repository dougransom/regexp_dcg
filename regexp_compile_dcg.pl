:- module(regexp_dcg, [
    re_match/3,
    re_match_t/3,
    re_match_groups/4,
    re_match_groups_t/5,
    re_compile/2,
    re_match_dcg//2,
    re_match_dcg//3,
    re_match_dcg_state//4,
    re_clear_cache/0,
    pattern_cache/3,
    pattern_ast/2,
    ast_dcg/4,
    ast_dcg_/4,
    dcg_lit//3,
    dcg_concat//3,
    dcg_or//4,
    dcg_capture//4,
    dcg_star//3,
    dcg_plus//3,
    dcg_question//3,
    dcg_quant//5,
    dcg_dot//2,
    dcg_bol/4,
    dcg_eol/4,
    dcg_builtin//3,
    dcg_class//3,
    dcg_lookahead/5,
    dcg_neg_lookahead/5,
    dcg_star_lazy//3,
    dcg_plus_lazy//3,
    dcg_question_lazy//3,
    dcg_quant_lazy//5,
    dcg_named_capture//5,
    dcg_flags/5,
    dcg_flags_group//4
]).

:- use_module(regexp_ast).
:- use_module(logs).
:- use_module(library(si)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(error)).

:- dynamic(pattern_cache/3).

% Compile a pattern into a reusable compiled goal structure
re_compile(Pattern, compiled(Goal, GroupCount)) :-
    pattern_ast(Pattern, AST),
    ast_dcg_goal(AST, 0, GroupCount, Goal).

pattern_compiled(compiled(Goal, GroupCount), Goal, GroupCount) :- !.
pattern_compiled(Pattern, Goal, GroupCount) :-
    to_chars(Pattern, Key),
    (   pattern_cache(Key, Goal0, GroupCount0) ->
        Goal = Goal0,
        GroupCount = GroupCount0
    ;   pattern_ast(Pattern, AST),
        ast_dcg_goal(AST, 0, GroupCount, Goal),
        assertz(pattern_cache(Key, Goal, GroupCount))
    ).

re_clear_cache :-
    retractall(pattern_cache(_, _, _)).

% Most common: just get the full match
re_match(Pattern, Input, Match) :-
    re_match_groups(Pattern, Input, Match, _Groups).

% reif compatible re_match_t/3
re_match_t(Pattern, Input, T) :-
    (   re_match(Pattern, Input, _) ->
        T = true
    ;   T = false
    ).

% Richer: full match + numbered groups
re_match_groups(Pattern, Input, Match, Groups) :-
    pattern_compiled(Pattern, Goal, GroupCount),
    length(Groups, GroupCount),
    to_chars(Input, Chars),
    S0 = state(Chars, Groups, [], []),
    phrase(call(Goal, S0, SF), Chars),
    state_match(SF, Match),
    state_groups(SF, Groups).

% reif compatible re_match_groups_t/5
re_match_groups_t(Pattern, Input, Match, Groups, T) :-
    (   re_match_groups(Pattern, Input, Match0, Groups0) ->
        T = true,
        Match = Match0,
        Groups = Groups0
    ;   T = false
    ).

% DCG phrase matcher helpers

re_match_dcg(Pattern, Match) -->
    re_match_dcg(Pattern, Match, _Groups).

re_match_dcg(Pattern, Match, Groups) -->
    re_match_dcg_state(Pattern, Match, _S0, SF),
    {
        state_groups(SF, Groups)
    }.

re_match_dcg_state(Pattern, Match, S0, SF, L0, L) :-
    pattern_compiled(Pattern, Goal, GroupCount),
    (   var(S0) ->
        length(Groups, GroupCount),
        S0 = state(L0, Groups, [], [])
    ;   S0 = state(L0, _, _, _)
    ),
    call(Goal, S0, SF, L0, L),
    append(Match, L, L0).

% Pattern already an AST
pattern_ast(AST, AST) :-
    is_ast(AST),
    !.

% Pattern is a string/atom: tokenize + parse
pattern_ast(Pattern, AST) :-
    to_chars(Pattern, Chars),
    phrase(re_ast_chars(AST), Chars).

is_ast(lit(_)).
is_ast(class(_)).
is_ast(anchor(_)).
is_ast(boundary(_)).
is_ast(group(_)).
is_ast(capture(_)).
is_ast(lookahead(_)).
is_ast(neg_lookahead(_)).
is_ast(quant(_, _)).
is_ast(postfix(_, _)).
is_ast(star(_)).
is_ast(plus(_)).
is_ast(maybe(_)).
is_ast(concat(_)).
is_ast(concat(_, _)).
is_ast(or(_, _)).
is_ast(escaped(_)).
is_ast(dot).
is_ast(named_capture(_, _)).
is_ast(flags(_)).
is_ast(flags(_, _)).

state(_Full, _Groups, _Named, _Tree).

state_full(state(Full, _, _, _), Full).
state_groups(state(_, Groups, _, _), Groups).
state_named(state(_, _, Named, _), Named).
state_tree(state(_, _, _, Tree), Tree).

initial_state(state(_, [], [], _)).

state_match(State, Match) :-
    state_full(State, Match).

% ast_dcg(+AST, +State0, -StateF, -DCG)
ast_dcg(AST, S0, SF, DCG) :-
    ast_dcg_goal(AST, 0, _, Goal),
    DCG = call(Goal, S0, SF).

% ast_dcg_/4 - kept for backward-compatibility / trace purposes
ast_dcg_(AST, S0, SF, call(Goal, S0, SF)) :-
    ast_dcg_goal(AST, 0, _, Goal).

% ast_dcg_goal(+AST, +C0, -CF, -Goal)
% Compiles the AST into a runtime DCG goal that threads SIn -> SOut at match-time,
% while counting capture group indices C0 -> CF.
ast_dcg_goal(lit(Chars), C, C, regexp_dcg:dcg_lit(Chars)).
ast_dcg_goal(concat(A, B), C0, CF, regexp_dcg:dcg_concat([GA, GB])) :-
    !,
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(concat(List), C0, CF, regexp_dcg:dcg_concat(SubGoals)) :-
    seq_ast_dcg(List, C0, CF, SubGoals).
ast_dcg_goal(or(A, B), C0, CF, regexp_dcg:dcg_or(GA, GB)) :-
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(group(Inner), C0, CF, Goal) :-
    ast_dcg_goal(Inner, C0, CF, Goal).
ast_dcg_goal(capture(Inner), C0, CF, regexp_dcg:dcg_capture(C0, GInner)) :-
    C1 is C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(postfix(Expr, star), C0, CF, regexp_dcg:dcg_star(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, plus), C0, CF, regexp_dcg:dcg_plus(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, question), C0, CF, regexp_dcg:dcg_question(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, mn(M, N)), C0, CF, regexp_dcg:dcg_quant(GExpr, M, N)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(dot, C, C, regexp_dcg:dcg_dot).
ast_dcg_goal(escaped(Char), C, C, regexp_dcg:dcg_lit([Char])).
ast_dcg_goal(anchor(bol), C, C, regexp_dcg:dcg_bol).
ast_dcg_goal(anchor(eol), C, C, regexp_dcg:dcg_eol).
ast_dcg_goal(builtin(Class), C, C, regexp_dcg:dcg_builtin(Class)).
ast_dcg_goal(class(Items), C, C, regexp_dcg:dcg_class(Items)).
ast_dcg_goal(lookahead(Sub), C0, CF, regexp_dcg:dcg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(neg_lookahead(Sub), C0, CF, regexp_dcg:dcg_neg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(postfix(Expr, lazy(star)), C0, CF, regexp_dcg:dcg_star_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(plus)), C0, CF, regexp_dcg:dcg_plus_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(question)), C0, CF, regexp_dcg:dcg_question_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, lazy(mn(M, N))), C0, CF, regexp_dcg:dcg_quant_lazy(GExpr, M, N)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(named_capture(Name, Inner), C0, CF, regexp_dcg:dcg_named_capture(Name, C0, GInner)) :-
    !,
    C1 is C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(flags(Flags), C, C, regexp_dcg:dcg_flags(Flags)).
ast_dcg_goal(flags(Flags, Sub), C0, CF, regexp_dcg:dcg_flags_group(Flags, GSub)) :-
    !,
    ast_dcg_goal(Sub, C0, CF, GSub).

seq_ast_dcg([], C, C, []).
seq_ast_dcg([H|T], C0, CF, [G|Gs]) :-
    ast_dcg_goal(H, C0, C1, G),
    seq_ast_dcg(T, C1, CF, Gs).

% DCG for literal matching
literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).

% Convert input to character list safely without SWI-specifics (list_si checked first!)
to_chars(Input, Input) :-
    list_si(Input),
    !.
to_chars(Input, Chars) :-
    atom_si(Input),
    !,
    atom_chars(Input, Chars).
to_chars(Input, _) :-
    domain_error(chars, Input).

/* ---------- Runtime DCG combinators ---------- */

dcg_lit(Chars, S0, SF) -->
    { S0 = state(_, _, _, Flags),
      member(case_insensitive, Flags) },
    !,
    literal_match_case_insensitive(Chars),
    { SF = S0 }.
dcg_lit(Chars, S0, S0) -->
    literal_match(Chars).

dcg_concat([], S, S) --> [].
dcg_concat([G|Gs], S0, SF) -->
    call(G, S0, S1),
    dcg_concat(Gs, S1, SF).

dcg_or(GA, GB, S0, SF) -->
    call(GA, S0, SF)
  ; call(GB, S0, SF).

dcg_capture(Index, GInner, S0, SF) -->
    match_consumed(call(GInner, S0, SF), Match),
    {
        S0 = state(_, Groups, _, _),
        nth0(Index, Groups, Match)
    }.

match_consumed(Goal, Consumed, S0, S) :-
    phrase(Goal, S0, S),
    append(Consumed, S, S0).

dcg_star(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    dcg_star(GExpr, S1, SF)
  ; { S0 = SF }.

dcg_plus(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    (   dcg_star(GExpr, S1, SF)
    ;   { S1 = SF }
    ).

dcg_question(GExpr, S0, SF) -->
    call(GExpr, S0, SF)
  ; { S0 = SF }.

dcg_quant(GExpr, M, N, S0, SF) -->
    { ( N == inf -> Max = inf ; integer(N) -> Max = N ) },
    dcg_quant_loop(GExpr, 0, M, Max, S0, SF).

dcg_quant_loop(GExpr, Count, Min, Max, S0, SF) -->
    { (Max == inf ; Count < Max) },
    call(GExpr, S0, S1),
    { Count1 is Count + 1 },
    dcg_quant_loop(GExpr, Count1, Min, Max, S1, SF).

dcg_quant_loop(_GExpr, Count, Min, _Max, S, S) -->
    { Count >= Min }.

dcg_dot(S, S) -->
    [_].

dcg_bol(S, S, L0, L0) :-
    S = state(Full, _, _, _),
    L0 == Full.

dcg_eol(S, S, [], []).

dcg_builtin(Class, S, S) -->
    [C],
    { match_builtin(Class, C) }.

match_builtin(digit, C) :-
    C @>= '0', C @=< '9'.
match_builtin(not_digit, C) :-
    \+ (C @>= '0', C @=< '9').
match_builtin(word, C) :-
    (C @>= 'a', C @=< 'z') ; (C @>= 'A', C @=< 'Z') ; (C @>= '0', C @=< '9') ; C == '_'.
match_builtin(not_word, C) :-
    \+ match_builtin(word, C).
match_builtin(space, C) :-
    member(C, [' ', '\t', '\r', '\n']).
match_builtin(not_space, C) :-
    \+ match_builtin(space, C).

dcg_class(Items, S0, SF) -->
    [C],
    { S0 = SF,
      S0 = state(_, _, _, Flags),
      (   member(case_insensitive, Flags) ->
          match_class_ci(Items, C)
      ;   match_class(Items, C)
      )
    }.

match_class(neg(List), C) :-
    !,
    \+ match_class_list(List, C).
match_class(List, C) :-
    list_si(List),
    match_class_list(List, C).

match_class_list([H|T], C) :-
    (   match_class_item(H, C) ->
        true
    ;   match_class_list(T, C)
    ).

match_class_item(char(C), C).
match_class_item(range(A, B), C) :-
    C @>= A, C @=< B.
match_class_item(builtin(Class), C) :-
    match_builtin(Class, C).

match_class_ci(neg(List), C) :-
    !,
    \+ match_class_list_ci(List, C).
match_class_ci(List, C) :-
    list_si(List),
    match_class_list_ci(List, C).

match_class_list_ci([H|T], C) :-
    (   match_class_item_ci(H, C) ->
        true
    ;   match_class_list_ci(T, C)
    ).

match_class_item_ci(char(CharPattern), C) :-
    char_equal_ci(CharPattern, C).
match_class_item_ci(range(A, B), C) :-
    char_lower(A, LowerA),
    char_lower(B, LowerB),
    char_lower(C, LowerC),
    LowerC @>= LowerA, LowerC @=< LowerB.
match_class_item_ci(builtin(Class), C) :-
    match_builtin(Class, C).

dcg_lookahead(GSub, S0, SF, L0, L0) :-
    phrase(call(GSub, S0, SF), L0, _).

dcg_neg_lookahead(GSub, S0, S0, L0, L0) :-
    \+ phrase(call(GSub, S0, _), L0, _).

/* ---------- Lazy combinators ---------- */

dcg_star_lazy(GExpr, S0, SF) -->
    { S0 = SF }
  ; call(GExpr, S0, S1),
    dcg_star_lazy(GExpr, S1, SF).

dcg_plus_lazy(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    dcg_star_lazy(GExpr, S1, SF).

dcg_question_lazy(GExpr, S0, SF) -->
    { S0 = SF }
  ; call(GExpr, S0, SF).

dcg_quant_lazy(GExpr, M, N, S0, SF) -->
    { ( N == inf -> Max = inf ; integer(N) -> Max = N ) },
    dcg_quant_loop_lazy(GExpr, 0, M, Max, S0, SF).

dcg_quant_loop_lazy(_GExpr, Count, Min, _Max, S, S) -->
    { Count >= Min }.
dcg_quant_loop_lazy(GExpr, Count, Min, Max, S0, SF) -->
    { (Max == inf ; Count < Max) },
    call(GExpr, S0, S1),
    { Count1 is Count + 1 },
    dcg_quant_loop_lazy(GExpr, Count1, Min, Max, S1, SF).

/* ---------- Named capture combinator ---------- */

dcg_named_capture(Name, Index, GInner, S0, SF) -->
    match_consumed(call(GInner, S0, S1), Match),
    {
        S1 = state(Full, Groups, Named, Tree),
        nth0(Index, Groups, Match),
        SF = state(Full, Groups, [Name-Match|Named], Tree)
    }.

/* ---------- Case-insensitive support helpers ---------- */

parse_flags(Flags, Parsed) :-
    to_chars(Flags, Chars),
    map_flags(Chars, Parsed).

map_flags([], []).
map_flags([C|Cs], [P|Ps]) :-
    map_flag_char(C, P),
    map_flags(Cs, Ps).

map_flag_char('i', case_insensitive).

char_lower(C, L) :-
    (   C @>= 'A', C @=< 'Z' ->
        char_code(C, Code),
        LowerCode is Code + 32,
        char_code(L, LowerCode)
    ;   L = C
    ).

char_equal_ci(C1, C2) :-
    char_lower(C1, L),
    char_lower(C2, L).

literal_match_case_insensitive([]) --> [].
literal_match_case_insensitive([C|Cs]) -->
    [X],
    { char_equal_ci(C, X) },
    literal_match_case_insensitive(Cs).

/* ---------- Inline flags combinators ---------- */

dcg_flags(Flags, S0, SF, L, L) :-
    S0 = state(Full, Groups, Named, OldFlags),
    parse_flags(Flags, NewFlags),
    append(NewFlags, OldFlags, CombinedFlags),
    SF = state(Full, Groups, Named, CombinedFlags).

dcg_flags_group(Flags, GSub, S0, SF) -->
    {
        S0 = state(Full, Groups, Named, OldFlags),
        parse_flags(Flags, NewFlags),
        append(NewFlags, OldFlags, CombinedFlags),
        S1 = state(Full, Groups, Named, CombinedFlags)
    },
    call(GSub, S1, S2),
    {
        S2 = state(Full2, Groups2, Named2, _),
        SF = state(Full2, Groups2, Named2, OldFlags)
    }.

/*
   ========================================================================
   FAQ: Why are standard control operators (->, \+) used here instead of
        pure reified predicates (library(reif))?
   ========================================================================

   1. Standard Negation (\+) in Character Classes:
      Reifying a complex search check like match_class_list/2 (which handles
      ranges, standard term comparisons, and built-in digit/word classes)
      into a truth value (e.g., match_class_list_t/3) would be highly verbose
      and slow due to meta-call and boolean logical conjunction overheads.
      Since input characters are instantiated at matching time, standard
      negation-by-failure (\+) is safe, sound, and extremely performant.

   2. Control Flow (->) instead of if_/3:
      Standard -> is used for ground/instantiated check conditions, such as
      member(case_insensitive, Flags). When the condition is ground and
      deterministic, -> behaves purely and does not prune any alternative
      unification paths. In Scryer Prolog, it is compiled to a performant
      VM instruction, avoiding the overhead of invoking reified auxiliary
      predicates.
*/

 