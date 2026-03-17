:- module(regexp_dcg, [
    re_match/3,
    re_match_groups/4,
    pattern_ast/2,
    ast_dcg/4,
    ast_dcg_/4
    % later: re_match_named/4, re_match_tree/4
]).
:- use_module(regexp_ast).


% Most common: just get the full match
re_match(Pattern, Input, Match) :-
    re_match_groups(Pattern, Input, Match, _Groups).

% Richer: full match + numbered groups
re_match_groups(Pattern, Input, Match, Groups) :-
    pattern_ast(Pattern, AST),
  
    initial_state(S0),
    ast_dcg(AST, S0, SF, DCG),
  
    to_chars(Input, Chars),
  
    phrase(DCG, Chars),
  
    state_match(SF, Match),
    state_groups(SF, Groups).

% Pattern already an AST
pattern_ast(AST, AST) :-
    nonvar(AST),
    !.

% Pattern is a string/atom: tokenize + parse
pattern_ast(Pattern, AST) :-
    phrase(re_ast_chars(AST), Pattern).

state(_Full, _Groups, _Named, _Tree).

state_full(state(Full, _, _, _), Full).
state_groups(state(_, Groups, _, _), Groups).
state_named(state(_, _, Named, _), Named).
state_tree(state(_, _, _, Tree), Tree).

initial_state(state(_, [], [], _)).

state_match(State, Match) :-
    state_full(State,Match).


% ast_dcg(+AST, +State0, -StateF, -DCG)
ast_dcg(AST, S0, SF, DCG) :-
    ast_dcg_(AST, S0, SF, DCG).

% ast_dcg_/4 - compile AST to DCG
ast_dcg_(lit(Chars), S, S, DCG) :-
    DCG = literal_match(Chars).

ast_dcg_(concat(List), S0, SF, DCG) :-
    seq_dcgs(List, S0, SF, DCG).

ast_dcg_(or(A, B), S0, SF, DCG) :-
    (   ast_dcg_(A, S0, SF, DCG)
    ;   ast_dcg_(B, S0, SF, DCG)
    ).

ast_dcg_(postfix(Expr, star), S0, SF, DCG) :-
    star_dcg(Expr, S0, SF, DCG).

ast_dcg_(postfix(Expr, plus), S0, SF, DCG) :-
    plus_dcg(Expr, S0, SF, DCG).

ast_dcg_(postfix(Expr, question), S0, SF, DCG) :-
    question_dcg(Expr, S0, SF, DCG).

% DCG for literal matching
literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).

% Convert input to character list
to_chars(Input, Chars) :-
    atom(Input),
    atom_chars(Input, Chars),
    !.
to_chars(Input, Chars) :-
    string(Input),
    string_chars(Input, Chars),
    !.
to_chars(Input, Input) :-
    is_list(Input),
    !.

% Helper to sequence multiple DCGs
seq_dcgs([], S, S, []) --> [].
seq_dcgs([H|T], S0, SF, [DCG|DCGs]) -->
    ast_dcg_(H, S0, S1, DCG),
    seq_dcgs(T, S1, SF, DCGs).

% Quantifier implementations
star_dcg(Expr, S0, SF, DCG) -->
    (   ast_dcg_(Expr, S0, S1, _),
        star_dcg(Expr, S1, SF, DCG)
    ;   { S0 = SF, DCG = [] }
    ).

plus_dcg(Expr, S0, SF, DCG) -->
    ast_dcg_(Expr, S0, S1, _),
    (   ast_dcg_(Expr, S1, SF, DCG)
    ;   { S1 = SF, DCG = [] }
    ).

question_dcg(Expr, S0, SF, DCG) -->
    (   ast_dcg_(Expr, S0, SF, DCG)
    ;   { S0 = SF, DCG = [] }
    ).
