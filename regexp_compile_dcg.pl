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
    atom(Pattern),
    atom_chars(Pattern, Chars),
    % you already have: chars -> tokens -> AST
    phrase(re_tokens(Tokens), Chars),
    phrase(re_ast(AST), Tokens).

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

% literal: lit([a,b,c])
ast_dcg_(lit(Chars), S, S, DCG) :-
    DCG = literal_match(Chars).

literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).


% literals, concat, alt, star, capture, etc. go into ast_dcg_/4

sequence([]) --> [].
sequence([C|Cs]) --> [C], sequence(Cs).

seq([]) --> [].
seq([D|Ds]) --> D, seq(Ds).
