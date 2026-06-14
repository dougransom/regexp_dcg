:- module(regexp_dcg, [
    re_match/3,
    re_match_groups/4,
    pattern_ast/2,
    ast_dcg/4,
    ast_dcg_/4
    % later: re_match_named/4, re_match_tree/4
]).

:- use_module(regexp_ast).
:- use_module(logs).
:- use_module(library(si)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).

% Most common: just get the full match
re_match(Pattern, Input, Match) :-
    re_match_groups(Pattern, Input, Match, _Groups).

% Richer: full match + numbered groups
re_match_groups(Pattern, Input, Match, Groups) :-
    pattern_ast(Pattern, AST),
    initial_state(S0),
    ast_dcg(AST, S0, SF, DCG),
    to_chars(Input, Chars),
    phrase(DCG, Chars),
    S0 = state(Chars, _, _, _),
    state_match(SF, Match),
    state_groups(SF, Groups).

% Pattern already an AST (is not a list or atom pattern)
pattern_ast(AST, AST) :-
    nonvar(AST),
    \+ (list_si(AST) ; atom_si(AST)),
    !.

% Pattern is a string/atom: tokenize + parse
pattern_ast(Pattern, AST) :-
    (   atom_si(Pattern) -> atom_chars(Pattern, Chars) ; Chars = Pattern   ),
    phrase(re_ast_chars(AST), Chars).

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
    ast_dcg(AST, Goal),
    DCG = call(Goal, S0, SF).

% ast_dcg_/4 - kept for backward-compatibility / trace purposes
ast_dcg_(AST, S0, SF, call(Goal, S0, SF)) :-
    ast_dcg(AST, Goal).

% ast_dcg(+AST, -Goal)
% Compiles the AST into a runtime DCG goal that threads SIn -> SOut at match-time.
ast_dcg(lit(Chars), regexp_dcg:dcg_lit(Chars)).
ast_dcg(concat(List), regexp_dcg:dcg_concat(SubGoals)) :-
    maplist(ast_dcg, List, SubGoals).
ast_dcg(or(A, B), regexp_dcg:dcg_or(GA, GB)) :-
    ast_dcg(A, GA),
    ast_dcg(B, GB).
ast_dcg(group(Inner), Goal) :-
    ast_dcg(Inner, Goal).
ast_dcg(capture(Inner), regexp_dcg:dcg_capture(GInner)) :-
    ast_dcg(Inner, GInner).
ast_dcg(postfix(Expr, star), regexp_dcg:dcg_star(GExpr)) :-
    ast_dcg(Expr, GExpr).
ast_dcg(postfix(Expr, plus), regexp_dcg:dcg_plus(GExpr)) :-
    ast_dcg(Expr, GExpr).
ast_dcg(postfix(Expr, question), regexp_dcg:dcg_question(GExpr)) :-
    ast_dcg(Expr, GExpr).

% DCG for literal matching
literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).

% Convert input to character list safely without SWI-specifics
to_chars(Input, Chars) :-
    (   atom_si(Input) -> atom_chars(Input, Chars)
    ;   list_si(Input) -> Chars = Input
    ;   domain_error(chars, Input)
    ).

/* ---------- Runtime DCG combinators ---------- */

dcg_lit(Chars, S, S) -->
    literal_match(Chars).

dcg_concat([], S, S) --> [].
dcg_concat([G|Gs], S0, SF) -->
    call(G, S0, S1),
    dcg_concat(Gs, S1, SF).

dcg_or(GA, GB, S0, SF) -->
    call(GA, S0, SF)
  ; call(GB, S0, SF).

dcg_capture(GInner, S0, SF) -->
    match_consumed(call(GInner, S0, S1), Match),
    {
        S1 = state(Full, Groups, Named, Tree),
        append(Groups, [Match], NewGroups),
        SF = state(Full, NewGroups, Named, Tree)
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
