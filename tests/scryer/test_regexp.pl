:- use_module('../testing').
:- use_module('../../src/regexp').
:- use_module(library(dcgs)).

:- discontiguous(test/2).

test("default tree engine matching",
    ( re_match("a*b", "aaabc", Rest),
      Rest == "c"
    )).

test("options mode(dcg) compile and match",
    ( re_compile("a*b", [mode(dcg)], Compiled),
      Compiled = compiled(_, _),
      phrase(re_match(Compiled, Match), "aaabc", Rest),
      Match == "aaab",
      Rest == "c"
    )).

test("options mode(dcg) direct list match",
    ( re_match("a*b", "aaabc", Rest, [mode(dcg)]),
      Rest == "c"
    )).

test("options mode(tree) compile and match",
    ( re_compile("a*b", [mode(tree)], CompiledTree),
      CompiledTree = compiled_tree(_, _),
      re_match(CompiledTree, "aaabc", Rest),
      Rest == "c"
    )).

test("options engine(dcg) direct list match_groups",
    ( re_match_groups("([a-z]+)-([0-9]+)", "abc-123", Match, Groups, [engine(dcg)]),
      Match == "abc-123",
      Groups == ["abc", "123"]
    )).

engine(regexp).

:- use_module('../portable/test_regexp_compile_shared').

test(Name, Goal) :-
    engine(Engine),
    shared_test(Engine, Name, Goal),
    \+ member(Name, ["word boundary", "word boundary complex"]).
