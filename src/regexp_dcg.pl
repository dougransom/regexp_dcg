/**
  Provides a Definite Clause Grammar (DCG) regular expression engine facade for ISO Prolog systems.

  Note: The primary entry point for regular expression matching is `regexp` (`src/regexp.pl`).
  This module re-exports the DCG-based regular expression matching interface implemented
  in `src/core/regexp_compile_dcg.pl` for direct access or backward compatibility.
*/
:- module(regexp_dcg, [
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

:- use_module('core/regexp_compile_dcg').
