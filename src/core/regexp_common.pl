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
    state_named/2,
    builtin_class_spec/2,
    match_builtin/2,
    match_builtin_t/3,
    char_range_t/4
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(library(clpz)).
:- use_module(library(reif)).

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
    LMatch #= LFull - LRest,
    take_n(LMatch, Full, Match).

%% take_n(+N, +List, -Prefix)
%
% Take first `N` elements from `List`.
take_n(0, _, []) :- !.
take_n(N, [H|T], [H|R]) :-
    N #> 0,
    N1 #= N - 1,
    take_n(N1, T, R).

%% state_full(+State, -Full)
state_full(state(Full, _, _, _), Full).

%% state_groups(+State, -Groups)
state_groups(state(_, Groups, _, _), Groups).

%% state_named(+State, -Named)
state_named(state(_, _, Named, _), Named).

/* Built-in and POSIX Character Class Specifications */

%% builtin_class_spec(+Class, -Specs)
% Declarative specification of built-in and POSIX character classes.
builtin_class_spec(digit, [range('0', '9')]).
builtin_class_spec('d',   [range('0', '9')]).

builtin_class_spec(word,  [range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')]).
builtin_class_spec('w',   [range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')]).

builtin_class_spec(space, [set([' ', '\t', '\r', '\n', '\f', '\v'])]).
builtin_class_spec('s',   [set([' ', '\t', '\r', '\n', '\f', '\v'])]).

builtin_class_spec(alnum, [range('a', 'z'), range('A', 'Z'), range('0', '9')]).
builtin_class_spec(alpha, [range('a', 'z'), range('A', 'Z')]).
builtin_class_spec(blank, [set([' ', '\t'])]).
builtin_class_spec(cntrl, [range('\x00\', '\x1F\'), char('\x7F\')]).
builtin_class_spec(graph, [range('!', '~')]).
builtin_class_spec(lower, [range('a', 'z')]).
builtin_class_spec(print, [range(' ', '~')]).
builtin_class_spec(punct, [set(['!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~'])]).
builtin_class_spec(upper, [range('A', 'Z')]).
builtin_class_spec(xdigit,[range('0', '9'), range('a', 'f'), range('A', 'F')]).

%% match_builtin(+Class, +Char)
% Pure logical match for built-in or POSIX character class.
match_builtin(Class, C) :-
    match_builtin_t(Class, C, true).

%% match_builtin_t(+Class, +Char, -Truth)
% Reified pure match for built-in or POSIX character class using first-argument indexing and if_/3.
match_builtin_t(not_digit, C, Truth) :- match_builtin_t(digit, C, T0), reif_not(T0, Truth).
match_builtin_t('D', C, Truth)       :- match_builtin_t(digit, C, T0), reif_not(T0, Truth).
match_builtin_t(not_word, C, Truth)  :- match_builtin_t(word, C, T0), reif_not(T0, Truth).
match_builtin_t('W', C, Truth)       :- match_builtin_t(word, C, T0), reif_not(T0, Truth).
match_builtin_t(not_space, C, Truth) :- match_builtin_t(space, C, T0), reif_not(T0, Truth).
match_builtin_t('S', C, Truth)       :- match_builtin_t(space, C, T0), reif_not(T0, Truth).

match_builtin_t(digit, C, Truth)     :- match_specs_t([range('0', '9')], C, Truth).
match_builtin_t('d', C, Truth)       :- match_specs_t([range('0', '9')], C, Truth).
match_builtin_t(word, C, Truth)      :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')], C, Truth).
match_builtin_t('w', C, Truth)       :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')], C, Truth).
match_builtin_t(space, C, Truth)     :- match_specs_t([set([' ', '\t', '\r', '\n', '\f', '\v'])], C, Truth).
match_builtin_t('s', C, Truth)       :- match_specs_t([set([' ', '\t', '\r', '\n', '\f', '\v'])], C, Truth).

match_builtin_t(alnum, C, Truth)     :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9')], C, Truth).
match_builtin_t(alpha, C, Truth)     :- match_specs_t([range('a', 'z'), range('A', 'Z')], C, Truth).
match_builtin_t(blank, C, Truth)     :- match_specs_t([set([' ', '\t'])], C, Truth).
match_builtin_t(cntrl, C, Truth)     :- match_specs_t([range('\x00\', '\x1F\'), char('\x7F\')], C, Truth).
match_builtin_t(graph, C, Truth)     :- match_specs_t([range('!', '~')], C, Truth).
match_builtin_t(lower, C, Truth)     :- match_specs_t([range('a', 'z')], C, Truth).
match_builtin_t(print, C, Truth)     :- match_specs_t([range(' ', '~')], C, Truth).
match_builtin_t(punct, C, Truth)     :- match_specs_t([set(['!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~'])], C, Truth).
match_builtin_t(upper, C, Truth)     :- match_specs_t([range('A', 'Z')], C, Truth).
match_builtin_t(xdigit, C, Truth)    :- match_specs_t([range('0', '9'), range('a', 'f'), range('A', 'F')], C, Truth).

match_specs_t([], _C, false).
match_specs_t([Spec|Specs], C, Truth) :-
    match_spec_item_t(Spec, C, T0),
    if_(T0 = true,
        Truth = true,
        match_specs_t(Specs, C, Truth)).

match_spec_item_t(range(Min, Max), C, Truth) :-
    char_range_t(Min, Max, C, Truth).
match_spec_item_t(char(Ch), C, Truth) :-
    =(Ch, C, Truth).
match_spec_item_t(set(List), C, Truth) :-
    member_char_t(C, List, Truth).

member_char_t(_C, [], false).
member_char_t(C, [H|T], Truth) :-
    if_(C = H,
        Truth = true,
        member_char_t(C, T, Truth)).

char_ge_t(A, B, true) :- A @>= B, !.
char_ge_t(_, _, false).

char_le_t(A, B, true) :- A @=< B, !.
char_le_t(_, _, false).

char_range_t(Min, Max, Char, Truth) :-
    if_(char_ge_t(Char, Min),
        char_le_t(Char, Max, Truth),
        Truth = false).

reif_not(true, false).
reif_not(false, true).
