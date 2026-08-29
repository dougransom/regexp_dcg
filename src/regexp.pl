/**
  Provides the primary regular expression matching facade for ISO Prolog systems.

  By default, this module uses the Rational Tree Automaton engine (`regexp_tree`).
  The Definite Clause Grammar (DCG) based engine (`regexp_compile_dcg`) is a direct,
  drop-in substitute which can be explicitly selected via options (`mode(dcg)` or `engine(dcg)`).

  ### Matching Interfaces & Engines

  1. **Default Tree Engine (Rational Tree Automaton)**:
     Compiles patterns into cyclic rational tree automata and matches using pure `if_/3` logic.
     ```prolog
     ?- re_match("a*b", "aaabc", Rest).
     % Rest = "c"
     ```

  2. **DCG Engine Mode Option (`mode(dcg)` / `engine(dcg)`)**:
     Compiles patterns into executable Prolog DCG goals.
     ```prolog
     ?- re_compile("a*b", [mode(dcg)], Compiled),
        phrase(re_match(Compiled, Match), "aaabc", Rest).
     ```

  3. **Direct Substitute**:
     `src/core/regexp_compile_dcg.pl` and `src/regexp_dcg.pl` remain available as direct substitutes.
*/
:- module(regexp, [
    re_match//1,
    re_match//2,
    re_match_groups//3,
    re_match_named//3,
    re_match/2,
    re_match/3,
    re_match/4,
    re_match_groups/4,
    re_match_groups/5,
    re_match_named/4,
    re_match_named/5,
    re_group/3,
    re_compile/2,
    re_compile/3,
    re_clear_cache/0,
    re_cache_info/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).

:- use_module('core/regexp_tree').
:- use_module('core/regexp_compile_dcg').
:- use_module('core/regexp_compile_dfa').
:- use_module('core/regexp_common', [re_group/3]).

%% re_compile(+Pattern, -Compiled)
re_compile(Pattern, Compiled) :-
    re_compile(Pattern, [], Compiled).

%% re_compile(+Pattern, +Options, -Compiled)
re_compile(Pattern, Options, Compiled) :-
    select_engine(Options, Engine),
    (   Engine == dcg ->
        regexp_compile_dcg:re_compile(Pattern, Compiled)
    ;   Engine == dfa ->
        regexp_compile_dfa:re_compile(Pattern, Compiled)
    ;   regexp_tree:re_tree_compile(Pattern, Compiled)
    ).

%% re_match(+Pattern, ?Chars)
re_match(Pattern, Chars) :-
    re_match(Pattern, Chars, []).

%% re_match(+Pattern, ?Chars, -Rest_or_Options)
re_match(Pattern, Chars, Arg3) :-
    (   is_options_list(Arg3) ->
        re_match(Pattern, Chars, [], Arg3)
    ;   dispatch_match(Pattern, Chars, Arg3, [])
    ).

%% re_match(+Pattern, ?Chars, -Rest, +Options) OR re_match(+Pattern, -Match)// (DCG //2)
re_match(Pattern, Arg2, Arg3, Arg4) :-
    (   is_options_list(Arg4) ->
        dispatch_match(Pattern, Arg2, Arg3, Arg4)
    ;   dispatch_match_groups(Pattern, Arg3, Arg2, _Groups, Arg4, [])
    ).

%% re_match(+Pattern)// (DCG //1)
re_match(Pattern, S0, S) :-
    dispatch_match(Pattern, S0, S, []).

%% re_match_groups(+Pattern, -Match, -Groups)// (DCG //3)
re_match_groups(Pattern, Match, Groups, S0, S) :-
    dispatch_match_groups(Pattern, S0, Match, Groups, S, []).

%% re_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_match_groups(Pattern, Chars, Match, Groups) :-
    re_match_groups(Pattern, Chars, Match, Groups, []).

%% re_match_groups(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   is_options_list(Arg5) ->
        dispatch_match_groups(Pattern, Arg2, Arg3, Arg4, [], Arg5)
    ;   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        dispatch_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5, [])
    ;   dispatch_match_groups(Pattern, Arg4, Arg2, Arg3, Arg5, [])
    ).

%% re_match_named(+Pattern, -Match, -NamedGroups)// (DCG //3)
re_match_named(Pattern, Match, NamedGroups, S0, S) :-
    dispatch_match_named(Pattern, S0, Match, NamedGroups, S, []).

%% re_match_named(+Pattern, ?Chars, -Match, -NamedGroups)
re_match_named(Pattern, Chars, Match, NamedGroups) :-
    re_match_named(Pattern, Chars, Match, NamedGroups, []).

%% re_match_named(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   is_options_list(Arg5) ->
        dispatch_match_named(Pattern, Arg2, Arg3, Arg4, [], Arg5)
    ;   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        dispatch_match_named(Pattern, Arg2, Arg3, Arg4, Arg5, [])
    ;   dispatch_match_named(Pattern, Arg4, Arg2, Arg3, Arg5, [])
    ).

%% re_clear_cache
re_clear_cache :-
    regexp_tree:re_tree_clear_cache,
    regexp_compile_dcg:re_clear_cache,
    regexp_compile_dfa:re_clear_cache.

%% re_cache_info(-Count, -Keys)
re_cache_info(Count, Keys) :-
    regexp_tree:re_tree_cache_info(Count, Keys).

/* Internal Engine Selection & Dispatch */

select_engine(Options, Engine) :-
    (   var(Options) ->
        Engine = tree
    ;   member(mode(E), Options) ->
        Engine = E
    ;   member(engine(E), Options) ->
        Engine = E
    ;   Engine = tree
    ).

is_options_list(Options) :-
    nonvar(Options),
    list_si(Options),
    (   member(mode(_), Options)
    ;   member(engine(_), Options)
    ).

dispatch_match(Compiled, Chars, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled(_, _),
    !,
    regexp_compile_dcg:re_match(Compiled, Chars, Rest).
dispatch_match(Compiled, Chars, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_tree(_, _),
    !,
    regexp_tree:re_tree_match(Compiled, Chars, Rest).
dispatch_match(Compiled, Chars, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_dfa(_, _),
    !,
    regexp_compile_dfa:re_match(Compiled, Chars, Rest).
dispatch_match(Pattern, Chars, Rest, Options) :-
    select_engine(Options, Engine),
    (   Engine == dcg ->
        regexp_compile_dcg:re_match(Pattern, Chars, Rest)
    ;   Engine == dfa ->
        regexp_compile_dfa:re_match(Pattern, Chars, Rest)
    ;   regexp_tree:re_tree_match(Pattern, Chars, Rest)
    ).

dispatch_match_groups(Compiled, Chars, Match, Groups, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled(_, _),
    !,
    regexp_compile_dcg:re_match_groups(Compiled, Chars, Match, Groups, Rest).
dispatch_match_groups(Compiled, Chars, Match, Groups, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_tree(_, _),
    !,
    regexp_tree:re_tree_match_groups(Compiled, Chars, Match, Groups, Rest).
dispatch_match_groups(Compiled, Chars, Match, Groups, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_dfa(_, _),
    !,
    regexp_compile_dfa:re_match_groups(Compiled, Chars, Match, Groups, Rest).
dispatch_match_groups(Pattern, Chars, Match, Groups, Rest, Options) :-
    select_engine(Options, Engine),
    (   Engine == dcg ->
        regexp_compile_dcg:re_match_groups(Pattern, Chars, Match, Groups, Rest)
    ;   Engine == dfa ->
        regexp_compile_dfa:re_match_groups(Pattern, Chars, Match, Groups, Rest)
    ;   regexp_tree:re_tree_match_groups(Pattern, Chars, Match, Groups, Rest)
    ).

dispatch_match_named(Compiled, Chars, Match, Named, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled(_, _),
    !,
    regexp_compile_dcg:re_match_named(Compiled, Chars, Match, Named, Rest).
dispatch_match_named(Compiled, Chars, Match, Named, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_tree(_, _),
    !,
    regexp_tree:re_tree_match_named(Compiled, Chars, Match, Named, Rest).
dispatch_match_named(Compiled, Chars, Match, Named, Rest, _Options) :-
    nonvar(Compiled),
    Compiled = compiled_dfa(_, _),
    !,
    regexp_compile_dfa:re_match_named(Compiled, Chars, Match, Named, Rest).
dispatch_match_named(Pattern, Chars, Match, Named, Rest, Options) :-
    select_engine(Options, Engine),
    (   Engine == dcg ->
        regexp_compile_dcg:re_match_named(Pattern, Chars, Match, Named, Rest)
    ;   Engine == dfa ->
        regexp_compile_dfa:re_match_named(Pattern, Chars, Match, Named, Rest)
    ;   regexp_tree:re_tree_match_named(Pattern, Chars, Match, Named, Rest)
    ).
