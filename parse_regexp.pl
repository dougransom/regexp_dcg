:-use_module(library(dcgs)).

% Postifix Operators

postfix(AST) --> 
    regexp_term(A), 
    (  "*", {AST = star(A)}
    ;   "+", {AST = star(A)}
    ;   "?", {AST = star(A)}
    ).

% Alternation

regexp(AST) -->
    seq(Seq),
    ( "|", 
        regexp(Rest),
        { AST=alt([Seq|RestList]),
        


