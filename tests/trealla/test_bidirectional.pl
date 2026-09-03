:- use_module('tests/trealla/trealla_loader').
:- use_module('tests/testing').
:- use_module('src/pure_regex').
:- use_module(library(lists)).
:- use_module(library(dif)).
:- use_module(library(dcgs)).

test("Bidirectional: exact literal match generation",
    (   re_match("ab", X),
        X == "ab"
    )).

test("Bidirectional: optional quantifier produces both alternatives",
    (   findall(Sol, re_match("aa?b", Sol), Sols),
        member("aab", Sols),
        member("ab", Sols)
    )).

test("Bidirectional: wildcard dot produces uninstantiated character variable",
    (   re_match("a.b", X),
        X = ['a', Y, 'b'],
        var(Y),
        dif(Y, '\n')
    )).

test("Bidirectional: alternation produces each branch",
    (   findall(Sol, re_match("cat|dog|fish", Sol), Sols),
        Sols == ["cat", "dog", "fish"]
    )).

test("Bidirectional: Kleene star produces incremental solutions",
    (   re_match("a*b", S0),
        S0 == "b",
        findall(Sol, (re_match("a*b", Sol), length(Sol, L), ( L >= 4 -> ! ; true )), Sols),
        member("b", Sols),
        member("ab", Sols),
        member("aab", Sols),
        member("aaab", Sols)
    )).

test("Bidirectional: Kleene plus produces incremental solutions starting at length 1",
    (   re_match("a+b", S0),
        S0 == "ab",
        findall(Sol, (re_match("a+b", Sol), length(Sol, L), ( L >= 4 -> ! ; true )), Sols),
        member("ab", Sols),
        member("aab", Sols),
        member("aaab", Sols)
    )).

test("Bidirectional: bounded range repetition {n,m}",
    (   findall(Sol, re_match("a{2,3}b", Sol), Sols),
        Sols == ["aaab", "aab"]
    )).

test("Bidirectional: pre-compiled tree automaton generation",
    (   re_compile("x|y|z", Compiled),
        findall(Sol, re_match(Compiled, Sol), Sols),
        Sols == ["x", "y", "z"]
    )).

test("Bidirectional: DCG non-terminal phrase generation",
    (   phrase(re_match("hello"), Out),
        Out == "hello"
    )).

test("Bidirectional: invalid input type raises domain_error",
    (   catch(re_match("ab", 123), Error, true),
        nonvar(Error),
        Error = error(domain_error(chars, 123), _)
    )).
