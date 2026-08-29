/**
  Provides the primary regular expression matching interface for ISO Prolog systems.

  By default, uses the Rational Tree Automaton engine (`regexp_tree`).
  If `user:regexp_mode(dcg)` or `user:regexp_mode(dfa)` is asserted (e.g. `assertz(user:regexp_mode(dcg))`),
  or if specified via options `[mode(Engine)]`, dispatches to that engine implementation.
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

:- use_module('core/regexp_tree').
:- use_module('core/regexp_compile_dcg').
:- use_module('core/regexp_compile_dfa').
:- use_module('core/regexp_common', [re_group/3]).

% Determines current engine: checks user:regexp_mode/1 or defaults to tree.
current_engine(Engine) :-
    (   catch(user:regexp_mode(E), _, fail) ->
        Engine = E
    ;   Engine = tree
    ).

select_mode([], _Engine) :- fail.
select_mode([Opt|Opts], Engine) :-
    (   (Opt = mode(E) ; Opt = engine(E)) ->
        Engine = E
    ;   select_mode(Opts, Engine)
    ).

is_options_list(Term) :-
    nonvar(Term),
    list_si(Term),
    (   Term == []
    ;   Term = [Head|_],
        nonvar(Head),
        compound(Head)
    ).

%% re_compile(+Pattern, -Compiled)
re_compile(Pattern, Compiled) :-
    re_compile(Pattern, [], Compiled).

%% re_compile(+Pattern, +Options, -Compiled)
re_compile(Pattern, Options, Compiled) :-
    (   select_mode(Options, Engine) -> true
    ;   current_engine(Engine)
    ),
    dispatch_compile(Engine, Pattern, Compiled).

dispatch_compile(dcg, Pattern, Compiled) :-
    regexp_compile_dcg:re_compile(Pattern, Compiled).
dispatch_compile(dfa, Pattern, Compiled) :-
    regexp_compile_dfa:re_compile(Pattern, Compiled).
dispatch_compile(tree, Pattern, Compiled) :-
    regexp_tree:re_tree_compile(Pattern, Compiled).

%% re_match(+Pattern, ?Chars)
re_match(Pattern, Chars) :-
    re_match(Pattern, Chars, []).

%% re_match(+Pattern, ?Chars, ?Arg3)
re_match(Pattern, Arg2, Arg3) :-
    (   is_options_list(Arg3) ->
        re_match(Pattern, Arg2, [], Arg3)
    ;   current_engine(Engine),
        dispatch_match3(Engine, Pattern, Arg2, Arg3)
    ).

dispatch_match3(dcg, Pattern, Chars, Rest) :-
    regexp_compile_dcg:re_match(Pattern, Chars, Rest).
dispatch_match3(dfa, Pattern, Chars, Rest) :-
    regexp_compile_dfa:re_match(Pattern, Chars, Rest).
dispatch_match3(tree, Pattern, Chars, Rest) :-
    regexp_tree:re_tree_match(Pattern, Chars, Rest).

%% re_match(+Pattern, ?Chars, -Rest, +Options)
re_match(Pattern, Chars, Rest, Options) :-
    (   select_mode(Options, Engine) -> true
    ;   current_engine(Engine)
    ),
    dispatch_match3(Engine, Pattern, Chars, Rest).

%% DCG non-terminals (always use DCG engine for DCG phrase compatibility)
re_match(Pattern, Match, S0, S) :-
    regexp_compile_dcg:re_match(Pattern, Match, S0, S).

re_match(Pattern, S0, S) :-
    regexp_compile_dcg:re_match(Pattern, S0, S).

re_match_groups(Pattern, Match, Groups, S0, S) :-
    regexp_compile_dcg:re_match_groups(Pattern, Match, Groups, S0, S).

re_match_named(Pattern, Match, Named, S0, S) :-
    regexp_compile_dcg:re_match_named(Pattern, Match, Named, S0, S).

%% re_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_match_groups(Pattern, Chars, Match, Groups) :-
    re_match_groups(Pattern, Chars, Match, Groups, []).

%% re_match_groups(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   is_options_list(Arg5) ->
        (   select_mode(Arg5, Engine) -> true ; current_engine(Engine) ),
        dispatch_groups4(Engine, Pattern, Arg2, Arg3, Arg4)
    ;   current_engine(Engine),
        dispatch_groups5(Engine, Pattern, Arg2, Arg3, Arg4, Arg5)
    ).

dispatch_groups4(dcg, Pattern, Chars, Match, Groups) :-
    regexp_compile_dcg:re_match_groups(Pattern, Chars, Match, Groups).
dispatch_groups4(dfa, Pattern, Chars, Match, Groups) :-
    regexp_compile_dfa:re_match_groups(Pattern, Chars, Match, Groups).
dispatch_groups4(tree, Pattern, Chars, Match, Groups) :-
    regexp_tree:re_tree_match_groups(Pattern, Chars, Match, Groups).

dispatch_groups5(dcg, Pattern, A2, A3, A4, A5) :-
    regexp_compile_dcg:re_match_groups(Pattern, A2, A3, A4, A5).
dispatch_groups5(dfa, Pattern, A2, A3, A4, A5) :-
    regexp_compile_dfa:re_match_groups(Pattern, A2, A3, A4, A5).
dispatch_groups5(tree, Pattern, A2, A3, A4, A5) :-
    regexp_tree:re_tree_match_groups(Pattern, A2, A3, A4, A5).

%% re_match_named(+Pattern, ?Chars, -Match, -Named)
re_match_named(Pattern, Chars, Match, Named) :-
    re_match_named(Pattern, Chars, Match, Named, []).

%% re_match_named(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   is_options_list(Arg5) ->
        (   select_mode(Arg5, Engine) -> true ; current_engine(Engine) ),
        dispatch_named4(Engine, Pattern, Arg2, Arg3, Arg4)
    ;   current_engine(Engine),
        dispatch_named5(Engine, Pattern, Arg2, Arg3, Arg4, Arg5)
    ).

dispatch_named4(dcg, Pattern, Chars, Match, Named) :-
    regexp_compile_dcg:re_match_named(Pattern, Chars, Match, Named).
dispatch_named4(dfa, Pattern, Chars, Match, Named) :-
    regexp_compile_dfa:re_match_named(Pattern, Chars, Match, Named).
dispatch_named4(tree, Pattern, Chars, Match, Named) :-
    regexp_tree:re_tree_match_named(Pattern, Chars, Match, Named).

dispatch_named5(dcg, Pattern, A2, A3, A4, A5) :-
    regexp_compile_dcg:re_match_named(Pattern, A2, A3, A4, A5).
dispatch_named5(dfa, Pattern, A2, A3, A4, A5) :-
    regexp_compile_dfa:re_match_named(Pattern, A2, A3, A4, A5).
dispatch_named5(tree, Pattern, A2, A3, A4, A5) :-
    regexp_tree:re_tree_match_named(Pattern, A2, A3, A4, A5).

re_clear_cache :-
    regexp_tree:re_tree_clear_cache,
    regexp_compile_dcg:re_clear_cache,
    regexp_compile_dfa:re_clear_cache.

re_cache_info(Engine, Info) :-
    (   Engine == dcg  -> regexp_compile_dcg:re_cache_info(dcg, Info)
    ;   Engine == dfa  -> regexp_compile_dfa:re_cache_info(dfa, Info)
    ;   regexp_tree:re_tree_cache_info(tree, Info)
    ).
