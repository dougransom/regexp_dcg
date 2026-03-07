:- module(regexp_ast, [
    re_expr//1
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1. TOKENIZER — flat list of atoms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_expr(AST) -->
    flat_expr(Tokens),
    { bind_postfix(Tokens, P1),
      parse_concat(P1, AST0),
      parse_alternation(AST0, AST)
    }.

%% flat_expr(-Atoms)
flat_expr([A|As]) -->
    flat_atom(A),
    flat_expr(As).
flat_expr([]) --> [].

%% flat_atom(-Atom)
flat_atom(lit(Cs)) -->
    literal_run(Cs).

flat_atom(dot)       --> ".".
flat_atom(caret)     --> "^".
flat_atom(dollar)    --> "$".
flat_atom(lparen)    --> "(".
flat_atom(rparen)    --> ")".
flat_atom(lbrack)    --> "[".
flat_atom(rbrack)    --> "]".
flat_atom(pipe)      --> "|".
flat_atom(star)      --> "*".
flat_atom(plus)      --> "+".
flat_atom(question)  --> "?".

flat_atom(escaped(C)) -->
    "\\", [C].

%% literal_run(-Chars)
literal_run([C|Cs]) -->
    [C],
    { \+ metachar(C) },
    literal_run_more(Cs).

literal_run_more([C|Cs]) -->
    [C],
    { \+ metachar(C) },
    literal_run_more(Cs).
literal_run_more([]) --> [].

%% metachar(+Char)
metachar(C) :-
    member(C, `.^$*+?()[]|\\{}`).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2. POSTFIX BINDING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

bind_postfix([], []).

bind_postfix([lit(Cs), plus | Rest], [postfix(lit(Cs), plus) | Out]) :-
    bind_postfix(Rest, Out).

bind_postfix([lit(Cs), star | Rest], [postfix(lit(Cs), star) | Out]) :-
    bind_postfix(Rest, Out).

bind_postfix([lit(Cs), question | Rest], [postfix(lit(Cs), question) | Out]) :-
    bind_postfix(Rest, Out).

bind_postfix([A | Rest], [A | Out]) :-
    bind_postfix(Rest, Out).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 3. CONCATENATION (left fold)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse_concat([A], A).
parse_concat([A,B|Rest], concat(A, C)) :-
    parse_concat([B|Rest], C).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 4. ALTERNATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse_alternation(concat(A, concat(pipe, B)), or(A1, B1)) :-
    parse_alternation(A, A1),
    parse_alternation(B, B1).

parse_alternation(concat(A, B), concat(A1, B1)) :-
    parse_alternation(A, A1),
    parse_alternation(B, B1).

parse_alternation(pipe, pipe).  % shouldn't appear alone
parse_alternation(X, X).
