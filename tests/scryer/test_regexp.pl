:- use_module('../testing').
:- use_module('../../src/regexp').
:- use_module('../../src/core/regexp_compile_dcg').
:- use_module(library(dcgs)).

:- discontiguous(test/2).

cleanup_mode :-
    ( catch(retractall(user:regexp_mode(_)), _, fail) -> true ; true ),
    ( catch(retract(user:regexp_mode(_)), _, fail) -> true ; true ).

test("default tree engine matching via regexp facade",
    ( cleanup_mode,
      regexp:re_compile("a*b", CompiledTree),
      CompiledTree = compiled_tree(_, _),
      regexp:re_match("a*b", "aaabc", Rest),
      Rest == "c"
    )).

test("user:regexp_mode(dcg) engine switching",
    ( cleanup_mode,
      assertz(user:regexp_mode(dcg)),
      regexp:re_compile("a*b", CompiledDCG),
      CompiledDCG = compiled(_, _),
      cleanup_mode
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
