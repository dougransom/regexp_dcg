:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(ast_dcg).
:- use_module(library(format)).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).



 test("Test Literal AST to DCG",
    (   In="abcdef",
        phrase(re_ast_chars(AST),In),
        AST = lit(In),
        ast_dcg(AST, Match, DCG),
        phrase(DCG, In),
        Match == In
        )).

test("Test Or Literals AST to DCG, nonveralapping matches",
    (
    phrase(re_ast_chars(AST),"abc|def"),
    AST = or(lit("abc"),lit("def")),
    ast_dcg(AST, Match, DCG),
    phrase(DCG, "abc"),
    Match == "abc"
    )).

test("Test Or Literals AST to DCG, longest match",
    (
    phrase(re_ast_chars(AST),"abc123|abc"),
    ast_dcg(AST, Match, DCG),
    phrase(DCG, "abc123xxx", _),
    Match == "abc123"
    )).


test("Capture AST to DCG, one captures",
 (  phrase(re_ast_chars(AST),"(abc)"),
    ast_dcg(AST, Match, DCG),
    phrase(DCG, "abc"),
    Match == "abc"
    )).
    
test("Capture AST to DCG, two captures",
 (  phrase(re_ast_chars(AST),"(abc)(def)"),
    ast_dcg(AST, Match, DCG),
    phrase(DCG, "abcdef"),
    Match == "abcdef"
    )).
