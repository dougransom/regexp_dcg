:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

% test("Force Fail",false).  %uncomment to see the test suites actually are doing something.

test("Force Pass",true).

%DCG Tests
test("Test Capture", 
    (phrase(re_tokens(T), "(abc)"),
    format("Tokens = ~w~n", [T]),
    phrase(re_expr_tokens(AST), T),
    AST=capture(lit("abc")),
    format("AST = ~w~n", [AST]))).

test("Postfix: simple literal with star",
    (   phrase(re_tokens(T), "a*"),
        phrase(re_expr_tokens(AST), T),
        T = [lit([a]), star],
        AST = postfix(lit([a]), star)
    )).

test("Postfix: capturing group with plus",
    (   phrase(re_tokens(T), "(abc)+"),
        phrase(re_expr_tokens(AST), T),
        T = [lparen, lit([a,b,c]), rparen, plus],
        AST = postfix(capture(lit([a,b,c])), plus)
    )).

test("Postfix: nested postfix inside noncapturing group",
    (   phrase(re_tokens(T), "(?:x+)+"),
        phrase(re_expr_tokens(AST), T),
        T = [lparen, question, colon, lit([x]), plus, rparen, plus],
        AST = postfix(group(postfix(lit([x]), plus)), plus)
    )).

test("Postfix: simple literal with ?",
    (   phrase(re_tokens(T), "a?"),
        phrase(re_expr_tokens(AST), T),
        T = [lit([a]), question],
        AST = postfix(lit([a]), question)
    )).