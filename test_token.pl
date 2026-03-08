:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

 test("Test Literal - simple string",
    (   In="abxa",
        phrase(re_token(T),In),
        T=lit("abxa")
        )).

 test("Test Literal - string with a `:`, which should provide three tokens",
    (   In="ab:xa",
        phrase(re_tokens(T),In),
        T = [lit("ab"),colon,lit("xa")]
        )).


 test("Test Literal - literal string followed by a single character and then a postfix operator",
    (   In="xyzabc?d",
        phrase(re_token(T),In,_),
        T=lit("xyzab")
        )).

 test("Test Literal - generate literal string from token",
    (   T=lit("xyzabc"),
        var(Str),
        phrase(re_token(T),Str),
        Str="xyzabc"
        )).


 test("Test escaped",
     (   
        %test relation both ways, String and token
        phrase(re_token(escaped(a)),Str),
        Str="\\a",
        phrase(re_token(T),Str),
        T=escaped(a)
        )).
test("Metachars ex escaped",
     %test by converting a string of metachars to tokens and back to strings again
    (Cs=".^$*+?()[]|{}",
    phrase(re_tokens(Ts),Cs),
    var(As),
    phrase(re_tokens(Ts),As),
    As=Cs
    )).

