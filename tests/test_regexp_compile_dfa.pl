% Unit tests for the experimental DFA regex compiler and matcher.

:- use_module('../bakage').
:- use_module(pkg(testing)).
:- use_module('../src/regexp_compile_dfa').
:- use_module(library(debug)).

:- discontiguous(test/2).

engine(regexp_dfa).

:- use_module(test_regexp_compile_shared).

test(Name, Goal) :-
    engine(Engine),
    shared_test(Engine, Name, Goal),
    \+ member(Name, ["6. assertion: lookahead"]).
