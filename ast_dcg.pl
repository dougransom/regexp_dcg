:- module(ast_dcg, [ast_dcg/2]).

%simple literal match, just use the literal as a DCG.
ast_dcg(lit(Lit),Lit).

%or construction, use | for alternation in the DCG.
ast_dcg(or(ast_dcg(_Left,LeftDCG),ast_dcg(_Right, RightDCG)), (LeftDCG|RightDCG)).  