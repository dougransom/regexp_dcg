% translate a regexp ast to a DCG for regexp pattern matching over strings.

:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(regexp_compile_dcg).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- dynamic(debug_mode/1).
debug_mode(on).

:- use_module(regexp_ast).   % your existing front-end



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
    (pattern_ast("abc", AST),
    dformat("\nAST: ~w", [AST]),
    ast_dcg(AST, _S0, _S1, DCG),
    dformat("\nDCG: ~w", [DCG]),
    dformat("\nTesting DCG phrase...", []),
    phrase(DCG, "abc") -> 
        dformat("\nDCG phrase succeeded", []) ; 
        dformat("\nDCG phrase failed", [])
    )).

test("simple match",
    (dformat("Testing re_match with 'abc' against 'abc'", []),
    re_match("abc", "abc", Match),
    dformat("\nMatch result: ~w", [Match]),
    assertion(Match == "abc"))).
