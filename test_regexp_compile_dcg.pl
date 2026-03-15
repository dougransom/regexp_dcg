:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(regexp_compile_dcg).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- set_debug(on).


test("simple match",
    (
    re_match("abc", "abc", Match),
    assertion(Match == "abc"))).
