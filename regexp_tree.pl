/**
  Provides a rational tree automaton regular expression matching interface for ISO Prolog systems.

  This module compiles regular expressions into rational tree (cyclic term) automata and matches
  them against character sequences using pure `if_/3` conditionals.

  ### Matching Interfaces

  1. **Direct List Matching**:
     ```prolog
     ?- re_tree_match("a*b", "aaabc", Rest).
     % Rest = "c"
     ```

  2. **DCG Non-Terminal Wrapper Matching (`re_tree_match//1-2`, `re_tree_match_groups//3`)**:
     ```prolog
     ?- phrase(re_tree_match("a*b", Match), "aaabc", Rest).
     % Match = "aaab", Rest = "c"
     ```

  3. **Pre-Compiling Rational Tree Automata (`re_tree_compile/2`)**:
     ```prolog
     ?- re_tree_compile("a*b", Tree), re_tree_match(Tree, "aaabc", Rest).
     ```
*/
:- module(regexp_tree, [
    re_tree_match//1,
    re_tree_match//2,
    re_tree_match_groups//3,
    re_tree_match_named//3,
    re_tree_group/3,
    re_tree_compile/2,
    re_tree_clear_cache/0,
    re_tree_cache_info/2,
    re_tree_match/2,
    re_tree_match/3,
    re_tree_match_groups/4,
    re_tree_match_groups/5,
    re_tree_match_named/4,
    re_tree_match_named/5,
    % Standard Engine Aliases for shared test runner compatibility
    re_match//1,
    re_match//2,
    re_match_groups//3,
    re_match_named//3,
    re_match/2,
    re_match/3,
    re_match_groups/4,
    re_match_groups/5,
    re_match_named/4,
    re_match_named/5,
    re_group/3,
    re_compile/2,
    re_clear_cache/0,
    re_cache_info/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).

:- use_module(src/regexp_ast, [re_ast_chars//1, is_ast/1]).
:- use_module(src/regexp_compile_tree, [compile_ast_tree/3, regex_tree_run/5]).

:- dynamic(tree_pattern_cache/3).

%% Standard Engine Aliases
re_match(Pattern, Chars) :- re_tree_match(Pattern, Chars).
re_match(Pattern, Chars, Rest) :- re_tree_match(Pattern, Chars, Rest).
re_match(Pattern, Match, S0, S) :- re_tree_match_groups_impl(Pattern, S0, Match, _Groups, S).
re_match_groups(Pattern, Chars, Match, Groups) :- re_tree_match_groups(Pattern, Chars, Match, Groups).
re_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :- re_tree_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5).
re_match_named(Pattern, Chars, Match, Named) :- re_tree_match_named(Pattern, Chars, Match, Named).
re_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :- re_tree_match_named(Pattern, Arg2, Arg3, Arg4, Arg5).
re_group(NamedGroups, Name, Value) :- re_tree_group(NamedGroups, Name, Value).
re_compile(Pattern, Compiled) :- re_tree_compile(Pattern, Compiled).
re_clear_cache :- re_tree_clear_cache.
re_cache_info(Count, Keys) :- re_tree_cache_info(Count, Keys).

%% re_tree_clear_cache
re_tree_clear_cache :-
    retractall(tree_pattern_cache(_, _, _)).

%% re_tree_cache_info(-Count, -Keys)
re_tree_cache_info(Count, Keys) :-
    findall(Key, tree_pattern_cache(Key, _, _), Keys),
    length(Keys, Count).

%% re_tree_group(+NamedGroups, +Name, -Value)
re_tree_group(NamedGroups, Name, Value) :-
    member(Name-Value, NamedGroups).

%% re_tree_compile(+Pattern, -CompiledTerm)
re_tree_compile(Pattern, compiled_tree(Automaton, GroupCount)) :-
    pattern_ast(Pattern, AST),
    compile_ast_tree(AST, Automaton, GroupCount).

%% re_tree_match(+Pattern, ?Chars)
re_tree_match(Pattern, Chars) :-
    re_tree_match(Pattern, Chars, []).

%% re_tree_match(+Pattern, ?Chars, -Rest)
re_tree_match(Pattern, Chars, Rest) :-
    re_tree_match_groups_impl(Pattern, Chars, _Match, _Groups, Rest).

%% re_tree_match(+Pattern, -Match)//
re_tree_match(Pattern, Match, S0, S) :-
    re_tree_match_groups_impl(Pattern, S0, Match, _Groups, S).

%% re_tree_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_tree_match_groups(Pattern, Chars, Match, Groups) :-
    re_tree_match_groups_impl(Pattern, Chars, Match, Groups, []).

%% re_tree_match_groups(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_tree_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        re_tree_match_groups_impl(Pattern, Arg2, Arg3, Arg4, Arg5)
    ;   re_tree_match_groups_impl(Pattern, Arg4, Arg2, Arg3, Arg5)
    ).

%% re_tree_match_named(+Pattern, ?Chars, -Match, -NamedGroups)
re_tree_match_named(Pattern, Chars, Match, NamedGroups) :-
    re_tree_match_named_impl(Pattern, Chars, Match, NamedGroups, []).

%% re_tree_match_named(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_tree_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        re_tree_match_named_impl(Pattern, Arg2, Arg3, Arg4, Arg5)
    ;   re_tree_match_named_impl(Pattern, Arg4, Arg2, Arg3, Arg5)
    ).

/* Internal Implementations */

re_tree_match_groups_impl(Pattern, Input, Match, Groups, Rest) :-
    to_chars(Input, Chars),
    get_tree_automaton(Pattern, Automaton, GroupCount),
    length(PosGroups, GroupCount),
    S0 = state(Chars, PosGroups, [], []),
    regex_tree_run(Chars, Automaton, S0, SF, Rest),
    state_groups(SF, Groups),
    extract_match(Chars, Rest, Match).

re_tree_match_named_impl(Pattern, Input, Match, NamedGroups, Rest) :-
    to_chars(Input, Chars),
    get_tree_automaton(Pattern, Automaton, GroupCount),
    length(PosGroups, GroupCount),
    S0 = state(Chars, PosGroups, [], []),
    regex_tree_run(Chars, Automaton, S0, SF, Rest),
    state_named(SF, NamedGroups),
    extract_match(Chars, Rest, Match).

/* Internal Helpers */

get_tree_automaton(Pattern, _, _) :-
    var(Pattern),
    !,
    instantiation_error(get_tree_automaton/3).
get_tree_automaton(compiled_tree(Automaton, GroupCount), Automaton, GroupCount) :- !.
get_tree_automaton(Pattern, Automaton, GroupCount) :-
    (   tree_pattern_cache(Pattern, AST, GroupCount) ->
        compile_ast_tree(AST, Automaton, GroupCount)
    ;   pattern_ast(Pattern, AST),
        compile_ast_tree(AST, Automaton, GroupCount),
        (   (list_si(Pattern) ; atom_si(Pattern)) ->
            assertz(tree_pattern_cache(Pattern, AST, GroupCount))
        ;   true
        )
    ).

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

state_groups(state(_, Groups, _, _), Groups).
state_named(state(_, _, Named, _), Named).

extract_match(Full, Rest, Match) :-
    length(Full, LFull),
    length(Rest, LRest),
    LMatch is LFull - LRest,
    take_n(LMatch, Full, Match).

take_n(0, _, []) :- !.
take_n(N, [H|T], [H|R]) :-
    N > 0,
    N1 is N - 1,
    take_n(N1, T, R).
