:- module(ast_dcg, [ast_dcg/2]).



dcg_combinator(dcg_longest_or).
dcg_combinator(dcg_capture).
term_expansion(DCG0, DCG) :-
    DCG0 =.. [Functor | Args],
    dcg_combinator(Functor),
    !,
    DCG =.. [Functor, ast_dcg | Args].
%simple literal match, just use the literal as a DCG.
ast_dcg(lit(Lit),Lit).

%or construction, use | for alternation in the DCG.
ast_dcg(or(L, R), DCG) :-
    ast_dcg(L, LDCG),
    ast_dcg(R, RDCG),
    DCG = ast_dcg:dcg_longest_or(LDCG, RDCG, _Match).


%capture construction.  

% ast_dcg(capture(Inner), dcg_capture(InnerDCG,Captured)) :-   
%     ast_dcg(Inner, InnerDCG).    
      
% dcg_capture(Inner, Match, S0, S) :-
%     phrase(Inner, S0, S),
%     append(Match, S, S0).

% dcg_capture(Inner, Match) -->
%     dcg_capture(Inner, Match).

dcg_longest_or(Module,L, R, Match, S0, S) :-
    phrase(Module:dcg_capture(L, ML), S0, SL),
    phrase(Module:dcg_capture(R, MR), S0, SR),
    length(ML, LenL),
    length(MR, LenR),
    (   LenL >= LenR
    ->  Match = ML, S = SL
    ;   Match = MR, S = SR
    ).

dcg_longest_or(Module,L, R, Match) -->
    Module:dcg_longest_or(Module,L, R, Match).

