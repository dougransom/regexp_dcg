:- module(ast_dcg, [
    ast_dcg/3, 
    run/3, 
    dcg_lit/4,
    dcg_capture/4, 
    dcg_longest_or/5,
    dcg_concat/4
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

/* ---------- AST → DCG ---------- */

% ast_dcg(+AST, -Match, -Goal)
% Returns a Goal that, when run via phrase/2, unifies Match with the consumed chars.

ast_dcg(lit(Lit), Match, dcg_lit(Lit, Match)).

ast_dcg(or(L, R), Match, dcg_longest_or(LDCG, RDCG, Match)) :-
    ast_dcg(L, _, LDCG),
    ast_dcg(R, _, RDCG).

ast_dcg(capture(Inner), Match, dcg_capture(InnerDCG, Match)) :-
    ast_dcg(Inner, _, InnerDCG).

ast_dcg(concat(A, B), Match, dcg_concat([A, B], Match)).

ast_dcg(concat(List), Match, dcg_concat(List, Match)).

/* ---------- DCG combinators ---------- */

dcg_lit(Lit, Match, S0, S) :-
    phrase(Lit, S0, S),
    Match = Lit.

dcg_concat(List, Match, S0, S) :-
    phrase(dcg_concat_list(List, Matches), S0, S),
    append(Matches, Match).

dcg_concat_list([], []) --> [].
dcg_concat_list([AST|T], [M|Ms]) -->
    { ast_dcg(AST, M, G) },
    G,
    dcg_concat_list(T, Ms).

dcg_capture(Inner, Match, S0, S) :-
    phrase(Inner, S0, S),
    append(Match, S, S0).

dcg_longest_or(L, R, Match, S0, S) :-
    findall(ML-SL, phrase(dcg_capture(L, ML), S0, SL), Ls),
    findall(MR-SR, phrase(dcg_capture(R, MR), S0, SR), Rs),
    append(Ls, Rs, All),
    (   All = [] -> fail
    ;   select_longest(All, Match, S)
    ).

select_longest([M-S|Rest], MaxM, MaxS) :-
    select_longest_(Rest, M, S, MaxM, MaxS).

select_longest_([], M, S, M, S).
select_longest_([M1-S1|Rest], M0, S0, MaxM, MaxS) :-
    length(M1, L1),
    length(M0, L0),
    (   L1 > L0
    ->  select_longest_(Rest, M1, S1, MaxM, MaxS)
    ;   select_longest_(Rest, M0, S0, MaxM, MaxS)
    ).

/* ---------- Wrapper to run DCGs inside this module ---------- */

run(D, S0, S) :-
    phrase(D, S0, S).
