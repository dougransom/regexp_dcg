/**
  Provides common input validation, pattern parsing, match extraction, and state accessors
  shared across all regular expression engines (`regexp_dcg`, `regexp_tree`, `regexp_dfa`).
*/
:- module(regexp_common, [
    to_chars/2,
    pattern_ast/2,
    re_group/3,
    extract_match/3,
    take_n/3,
    state_full/2,
    state_groups/2,
    state_named/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).

:- use_module(regexp_ast, [re_ast_chars//1, is_ast/1]).

%% to_chars(+Input, -Chars)
%
% Unify `Chars` with a list of character codes from string `Input` (character list or atom).
% Raises `instantiation_error` if `Input` is unbound, or `domain_error(chars, Input)` if invalid type.
to_chars(Input, _) :-
    var(Input),
    !,
    instantiation_error(to_chars/2).
to_chars(Input, Input) :-
    list_si(Input),
    !.
to_chars(Input, Chars) :-
    atom_si(Input),
    !,
    atom_chars(Input, Chars).
to_chars(Input, _) :-
    domain_error(chars, Input).

%% pattern_ast(+Pattern, -AST)
%
% Convert a pattern string, atom, or pre-built AST term into a canonical AST term.
pattern_ast(AST, _) :-
    var(AST),
    !,
    instantiation_error(pattern_ast/2).
pattern_ast(AST, AST) :-
    is_ast(AST),
    !.
pattern_ast(Pattern, AST) :-
    to_chars(Pattern, Chars),
    phrase(re_ast_chars(AST), Chars).

%% re_group(+NamedGroups, +Name, -Value)
%
% Lookup value of named group `Name` in `NamedGroups` key-value association list.
re_group(NamedGroups, Name, Value) :-
    member(Name-Value, NamedGroups).

%% extract_match(+Full, +Rest, -Match)
%
% Extract matched character sequence `Match` given original full input `Full` and remaining `Rest`.
extract_match(Full, Rest, Match) :-
    length(Full, LFull),
    length(Rest, LRest),
    LMatch is LFull - LRest,
    take_n(LMatch, Full, Match).

%% take_n(+N, +List, -Prefix)
%
% Take first `N` elements from `List`.
take_n(0, _, []) :- !.
take_n(N, [H|T], [H|R]) :-
    N > 0,
    N1 is N - 1,
    take_n(N1, T, R).

%% state_full(+State, -Full)
state_full(state(Full, _, _, _), Full).

%% state_groups(+State, -Groups)
state_groups(state(_, Groups, _, _), Groups).

%% state_named(+State, -Named)
state_named(state(_, _, Named, _), Named).
