:- use_module('tests/trealla/trealla_loader').
:- use_module('tests/testing').
:- use_module('src/core/regexp_compile_dfa').
:- use_module('tests/portable/test_regexp_compile_shared').
:- use_module(library(debug)).

run_shared :-
    shared_test(regexp_compile_dfa, Name, Goal),
    \+ member(Name, ["6. assertion: lookahead"]),
    register_test(Name, Goal),
    fail.
run_shared.

:- initialization(run_shared).
