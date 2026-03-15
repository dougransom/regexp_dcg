
:- module(regexp_dcg, [
    re_match/3,
    re_match_groups/4,
    set_debug/1,
    dformat/2,
    dformat/1
    % later: re_match_named/4, re_match_tree/4
]).
:- use_module(regexp_ast).   % your existing front-end
:-dynamic(debug_mode/1).


debug_mode(off).
set_debug(on)  :- retractall(debug_mode(_)), assertz(debug_mode(on)).
set_debug(off) :- retractall(debug_mode(_)), assertz(debug_mode(off)).

dformat(Format, Args) :-
    debug_mode(on),
    format(Format, Args).

dformat(_Format, _Args) :-
    debug_mode(off).

dformat(Message) :-
    debug_mode(on),
    writeln(Message).

dformat(_Message) :-
    debug_mode(off).



% Most common: just get the full match
re_match(Pattern, Input, Match) :-
    re_match_groups(Pattern, Input, Match, _Groups).

% Richer: full match + numbered groups
re_match_groups(Pattern, Input, Match, Groups) :-
    pattern_ast(Pattern, AST),
    dformat("AST: ~w~n", [AST]),

    initial_state(S0),
    ast_dcg(AST, S0, SF, DCG),
    dformat("Compiled DCG: ~w~n", [DCG]),

    to_chars(Input, Chars),
    dformat("Input chars: ~w~n", [Chars]),

    phrase(DCG, Chars),
    dformat("DCG succeeded.~n", []),

    state_match(SF, Match),
    state_groups(SF, Groups),
    dformat("Match: ~w~nGroups: ~w~n", [Match, Groups]).

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

% literals, concat, alt, star, capture, etc. go into ast_dcg_/4

sequence([]) --> [].
sequence([C|Cs]) --> [C], sequence(Cs).

seq([]) --> [].
seq([D|Ds]) --> D, seq(Ds).
