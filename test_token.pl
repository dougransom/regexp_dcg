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

 test("Test Literal - literal string followed by a single character and then a postfix operator",
    (   In="xyzabc?d",
        phrase(re_token(T),In,_),
        T=lit("xyzab")
        )).


 test("Test string - with escaped \\",
    (   In="\\\\a",
        phrase(re_token(T),In),
        T=lit("\\a")
        )).
        