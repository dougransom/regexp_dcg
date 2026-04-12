:- module(ast_dcg, [ast_dcg/2]).



dcg_combinator(dcg_longest_or).
dcg_combinator(dcg_capture).

term_expansion(T0, ast_dcg:T0) :-
    T0 =.. [Functor | _],
    dcg_combinator(Functor),
    \+ T0 = (_:_),   % do NOT rewrite already-qualified terms
    !.


%simple literal match, just use the literal as a DCG.
ast_dcg(lit(Lit),Lit).

%or construction, use | for alternation in the DCG.
ast_dcg(or(L, R), DCG) :-
    ast_dcg(L, LDCG),
    ast_dcg(R, RDCG),
    DCG = dcg_longest_or(LDCG, RDCG, _Match).


%capture construction.  

ast_dcg(capture(Inner), dcg_capture(InnerDCG,Captured)) :-   
     ast_dcg(Inner, InnerDCG).    
      
dcg_capture(Inner, Match, S0, S) :-
     phrase(Inner, S0, S),
     append(Match, S, S0).

 dcg_capture(Inner, Match) -->
     dcg_capture(Inner, Match).

dcg_longest_or(L, R, Match, S0, S) :-
    phrase(dcg_capture(L, ML), S0, SL),
    phrase(dcg_capture(R, MR), S0, SR),
    length(ML, LenL),
    length(MR, LenR),
    (   LenL >= LenR
    ->  Match = ML, S = SL
    ;   Match = MR, S = SR
    ).

dcg_longest_or(L, R, Match) -->
    dcg_longest_or(L, R, Match).

