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

test("Quantifier: exact repetition",
    (   phrase(re_tokens(T), "a{3}"),
        phrase(re_expr_tokens(AST), T),
        T = [lit("a"), lbrace, lit("3"), rbrace],
        AST = quant(lit("a"), mn(3,3))
    )).

test("Quantifier: bounded range",
    (   phrase(re_tokens(T), "b{2,5}"),
        phrase(re_expr_tokens(AST), T),
        T = [lit("b"), lbrace, lit("2"), comma, lit("5"), rbrace],
        AST = quant(lit("b"), mn(2,5))
    )).



test("Quantifier: open upper bound",
    (   phrase(re_tokens(T), "c{7,}"),
        phrase(re_expr_tokens(AST), T),
        T = [lit("c"), lbrace, lit("7"), comma, rbrace],
        AST = quant(lit("c"), mn(7,inf))
    )).

test("CharClass: simple class",
    (   phrase(re_tokens(T), "[abc]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([char(a),char(b),char(c)])],
        AST = class([char(a),char(b),char(c)])
    )).

test("CharClass: range",
    (   phrase(re_tokens(T), "[a-z]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([range(a,z)])],
        AST = class([range(a,z)])
    )).


test("CharClass: negated class",
    (   phrase(re_tokens(T), "[^abc]"),
        phrase(re_expr_tokens(AST), T),
        T = [class(neg([char(a),char(b),char(c)]))],
        AST = class(neg([char(a),char(b),char(c)]))
    )).
test("CharClass: negated range",
    (   phrase(re_tokens(T), "[^a-z]"),
        phrase(re_expr_tokens(AST), T),
        T = [class(neg([range(a,z)]))],
        AST = class(neg([range(a,z)]))
    )).

test("CharClass: escaped closing bracket",
    (   phrase(re_tokens(T), "[\\]]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([char(']')])],
        AST = class([char(']')])
    )).

test("CharClass: mixed items",
    (   phrase(re_tokens(T), "[a-z_]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([range(a,z), char(_)])],
        AST = class([range(a,z), char(_)])
    )).
test("CharClass: mixed ranges and chars",
    (   phrase(re_tokens(T), "[a-zA-Z_]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([range(a,z), range(A,Z), char(_)])],
        AST = class([range(a,z), range(A,Z), char(_)])
    )).

test("CharClass: negated mixed",
    (   phrase(re_tokens(T), "[^a-z_]"),
        phrase(re_expr_tokens(AST), T),
        T = [class(neg([range(a,z), char(_)]))],
        AST = class(neg([range(a,z), char(_)]))
    )).

test("CharClass: escaped hyphen",
    (   phrase(re_tokens(T), "[a\\-z]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([char(a), char('-'), char(z)])],
        AST = class([char(a), char('-'), char(z)])
    )).
test("CharClass: POSIX digit",
    (   phrase(re_tokens(T), "[[:digit:]]"),
        phrase(re_expr_tokens(AST), T),
        T = [class([posix(digit)])],
        AST = class([posix(digit)])
    )).
