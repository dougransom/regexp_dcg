:- module(regexp_ast, [
    re_expr//1,
    re_token//1,
    re_tokens//1,
    re_literal_run//1
    ]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1. TOP-LEVEL: tokenize → postfix → concat → alternation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_expr(AST) -->
    re_tokens(Toks),
    {
        bind_postfix(Toks, P1),
        parse_concat(P1, C0),
        parse_alternation(C0, AST)
    }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2. re_tokenIZER (DCG, deterministic, greedy)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_tokens([T|Ts]) --> re_token(T), !, re_tokens(Ts).
re_tokens([])     --> [].

%% re_token(-Tok)
re_token(lit(Cs)) -->
    re_literal_run(Cs), !.

re_token(escaped(C)) -->
    "\\", [C], !.

re_token(dot)      --> ".", !.
re_token(caret)    --> "^", !.
re_token(dollar)   --> "$", !.
re_token(lparen)   --> "(", !.
re_token(rparen)   --> ")", !.
re_token(lbrack)   --> "[", !.
re_token(rbrack)   --> "]", !.
re_token(pipe)     --> "|", !.
re_token(star)     --> "*", !.
re_token(plus)     --> "+", !.
re_token(question) --> "?", !.

look_ahead(T), [T] --> [T].

%% literal_run(-Chars)
%% The literal run is from the first literal character to the characer not preceeded by a postfix operator.
%% axd? 
%% or 
%% the first character followed by a postfix operator

re_literal_run([C|Cs]) -->
    [C], 
    { \+ metachar(C)},
    not_postfix_next_char,
    !,
    re_literal_run_more(Cs).

re_literal_run([C|Cs]) -->
    [C],
    postfix_next_char.


re_literal_run_more([C|Cs]) -->
    [C],
    { \+ metachar(C) },
    not_postfix_next_char,
    !,
    re_literal_run_more(Cs).


re_literal_run_more([]) --> [].

eos([], []).  %for detecting end of input, from https://www.metalevel.at/prolog/dcg

not_postfix_next_char --> call(eos) | (look_ahead(D), { \+ postfixchar(D) }).
postfix_next_char --> look_ahead(D), { postfixchar(D) }.

%% metachar(+Char)
metachar(C) :-
    member(C, ".^$*+?()[]|\\{}").
postfixchar(D) :-
    member(D,"*+?").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 3. POSTFIX BINDING
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
%% 4. CONCATENATION (left fold)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse_concat([A], A).
parse_concat([A,B|Rest], concat(A, C)) :-
    parse_concat([B|Rest], C).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 5. ALTERNATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

parse_alternation(concat(A, concat(pipe, B)), or(A1, B1)) :-
    parse_alternation(A, A1),
    parse_alternation(B, B1).

parse_alternation(concat(A, B), concat(A1, B1)) :-
    parse_alternation(A, A1),
    parse_alternation(B, B1).

parse_alternation(pipe, pipe).
parse_alternation(X,X).