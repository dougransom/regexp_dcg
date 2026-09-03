:- use_module('tests/trealla/trealla_loader').
:- use_module('tests/testing').
:- use_module('src/core/regexp_ast').
:- use_module('src/core/regexp_common').
:- use_module('src/core/regexp_compile_dcg').
:- use_module('tests/portable/test_regexp_compile_shared').
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

test("dcg for literal",
    ( regexp_common:pattern_ast("abc", AST),
      regexp_compile_dcg:ast_dcg(AST, _S0, _S1, DCG),
      phrase(DCG, "abc")
    )).

% Run shared DCG engine tests
run_shared :-
    shared_test(regexp_compile_dcg, Name, Goal),
    \+ member(Name, ["word boundary", "word boundary complex"]),
    testing:register_test(Name, Goal),
    fail.
run_shared.

:- initialization(run_shared).
