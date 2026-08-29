% translate a regexp ast to a DCG for regexp pattern matching over strings.

:- use_module('../testing').
:- use_module('../../src/core/regexp_ast').
:- use_module('../../src/core/regexp_common').
:- use_module('../../src/core/regexp_compile_dcg').
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- dynamic(debug_mode/1).
debug_mode(on).
:- discontiguous(test/2).

set_debug(on)  :- retractall(debug_mode(_)), assertz(debug_mode(on)).
set_debug(off) :- retractall(debug_mode(_)), assertz(debug_mode(off)).

dformat(Format, Args) :-
    debug_mode(on),
    format(Format, Args).

dformat(_Format, _Args) :-
    debug_mode(off).

dformat(Message) :-
    debug_mode(on),
    format('~w~n', [Message]).

dformat(_Message) :-
    debug_mode(off).

test("dcg for literal",
    (regexp_common:pattern_ast("abc", AST),
    dformat("\nAST: ~w", [AST]),
    regexp_compile_dcg:ast_dcg(AST, _S0, _S1, DCG),
    dformat("\nDCG: ~w", [DCG]),
    dformat("\nTesting DCG phrase...", []),
    phrase(DCG, "abc") -> 
        dformat("\nDCG phrase succeeded", []) ; 
        dformat("\nDCG phrase failed", [])
    )).

engine(regexp_compile_dcg).

:- use_module('../portable/test_regexp_compile_shared').

test(Name, Goal) :-
    engine(Engine),
    shared_test(Engine, Name, Goal),
    \+ member(Name, ["word boundary", "word boundary complex"]).
