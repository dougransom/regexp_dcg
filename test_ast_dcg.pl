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

test("Test Or and Literals AST to DCG",
    (
    phrase(re_ast_chars(Ast),"abc|def"),
    Ast = or(lit("abc"),lit("def")),
    ast_dcg(Ast,DCG),
    format("\nDCG: ~w~n", [DCG])
    
    )).