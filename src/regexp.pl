/**
  Provides the primary regular expression matching interface for ISO Prolog systems.

  By default, re-exports the Rational Tree Automaton engine (`regexp_tree`).
  If `user:regexp_mode(dcg)` or `user:regexp_mode(dfa)` is asserted prior to loading,
  re-exports that engine implementation instead.
*/
:- module(regexp, [
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
    re_compile/3,
    re_clear_cache/0,
    re_cache_info/2
]).

:- multifile(user:regexp_mode/1).

:- (   catch(user:regexp_mode(dcg), _, fail) ->
       use_module('core/regexp_compile_dcg')
   ;   catch(user:regexp_mode(dfa), _, fail) ->
       use_module('core/regexp_compile_dfa')
   ;   use_module('core/regexp_tree')
   ).
