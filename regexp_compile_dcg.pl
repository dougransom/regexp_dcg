:- module(regexp_dcg, [
    re_match/3,
    re_match_groups/4
    % later: re_match_named/4, re_match_tree/4
]).
:- use_module(regexp_ast).   % your existing front-end

dynamic(debug_mode).

debug_mode(off).
set_debug(on)  :- retractall(debug_mode(_)), assertz(debug_mode(on)).
set_debug(off) :- retractall(debug_mode(_)), assertz(debug_mode(off)).

dformat(Format, Args) :-
    debug_mode(on),
    !,
    format(Format, Args).
dformat(_, _).




% Most common: just get the full match
re_match(Pattern, Input, Match) :-
    re_match_groups(Pattern, Input, Match, _Groups).

% Richer: full match + numbered groups
re_match_groups(Pattern, Input, Match, Groups) :-
    pattern_ast(Pattern, AST),
    dprint("AST: ~w~n", [AST]),

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

initial_state(state{
    full: _,
    groups: [],
    named: captures{},   % later
    tree: _       % later
}).

state_match(State, Match) :-
    Match = State.full.

state_groups(State, Groups) :-
    Groups = State.groups.

% ast_dcg(+AST, +State0, -StateF, -DCG)
ast_dcg(AST, S0, SF, DCG) :-
    ast_dcg_(AST, S0, SF, DCG).

% literals, concat, alt, star, capture, etc. go into ast_dcg_/4

sequence([]) --> [].
sequence([C|Cs]) --> [C], sequence(Cs).

seq([]) --> [].
seq([D|Ds]) --> D, seq(Ds).
