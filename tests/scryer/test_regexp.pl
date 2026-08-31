:- use_module('../testing').
:- use_module('../../src/regexp').
:- use_module('../../src/core/regexp_compile_dcg').
:- use_module(library(dcgs)).

:- dynamic(user:regexp_mode/1).
:- multifile(user:regexp_mode/1).

:- discontiguous(test/2).

test("default tree engine matching via regexp facade",
    ( regexp:re_compile("a*b", CompiledTree),
      CompiledTree = compiled_tree(_, _),
      regexp:re_match("a*b", "aaabc", Rest),
      Rest == "c"
    )).

test("direct substitute DCG engine matching",
    ( regexp_compile_dcg:re_compile("a*b", Compiled),
      phrase(regexp_compile_dcg:re_match(Compiled, Match), "aaabc", Rest),
      Match == "aaab",
      Rest == "c"
    )).

engine(regexp).

:- use_module('../portable/test_regexp_compile_shared').

test(Name, Goal) :-
    engine(Engine),
    shared_test(Engine, Name, Goal),
    \+ member(Name, ["word boundary", "word boundary complex"]).
