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
        ast_dcg(Ast,DCG),
        DCG=In  
        )).

test("Test Or Literals AST to DCG, nonveralapping matches",
    (
    phrase(re_ast_chars(AST),"abc|def"),
    format("\nAST: ~w~n", [AST]),
    AST = or(lit("abc"),lit("def")),
    format("\nAST again: ~w~n", [AST]),
    ast_dcg(AST,DCG),
    format("\nDCG: ~w~n", [DCG])
    
    )).

test("Test Or Literals AST to DCG, longest matche",
    (
    phrase(re_ast_chars(AST),"abc123|abc"),
    format("\nAST: ~w~n", [AST]),
    ast_dcg(AST,DCG),
    format("\nDCG: ~w~n", [DCG])
    
    )).

test("Capture AST to DCG, one captures",
 (phrase(re_ast_chars(AT),"(abc)"),
    AT = concat([capture(lit("abc"))]),
    ast_dcg(AT,DCG),
    format("\nDCG: ~w~n", [DCG])
    )).
    
test("Capture AST to DCG, two captures",
 (phrase(re_ast_chars(AT),"(abc)(def)"),
    AT = concat([capture(lit("abc")), capture(lit("def"))]),
    ast_dcg(AT,DCG),
    format("\nDCG: ~w~n", [DCG])
    )).
