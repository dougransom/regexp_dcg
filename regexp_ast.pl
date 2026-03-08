:- module(regexp_ast, [
    re_expr//1,
    re_token//1,
    re_tokens//1,
    re_literal_run//1,
    re_literal_run_recognize//1,
    metachar/1,
    metachars/1
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1. TOP-LEVEL: tokenize → token-level DCG parser
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_expr(AST) -->
    re_tokens(Toks),
    phrase(re_expr_tokens(AST), Toks).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2. re_tokenIZER (DCG, deterministic, greedy)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_tokens([T|Ts]) --> re_token(T), !, re_tokens(Ts).
re_tokens([])     --> [].

%% re_token(-Tok)
%% re_token(-Tok) / re_token(+Tok)
%% If Cs is a variable: we are tokenizing input → use recognizer (greedy, lookahead).
%% If Cs is instantiated: we are generating output → use reversible version.

re_token(lit(Cs)) -->
    { var(Cs) },                 % tokenizing
    re_literal_run_recognize(Cs), !.

re_token(lit(Cs)) -->
    { nonvar(Cs) },              % generating
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
re_token(lbrace)   --> "{", !.
re_token(rbrace)   --> "}", !.
re_token(colon)    --> ":", !.

look_ahead(T), [T] --> [T].

re_literal_run(Cs) -->
    { Cs = [_|_] }, % nonempty
    sequence(Cs).

sequence([C|Cs]) --> [C], sequence(Cs).
sequence([]) --> [].

%% re_literal_run_recognize(-Chars)
%% The literal run is from the first literal character to the character
%% not preceded by a postfix operator.

re_literal_run_recognize([C|Cs]) -->
    [C],
    { \+ metachar(C) },
    not_postfix_next_char,
    !,
    re_literal_run_more(Cs).

re_literal_run_recognize([C]) -->
    [C],
    { \+ metachar(C) },
    postfix_next_char.

re_literal_run_more([C|Cs]) -->
    [C],
    { \+ metachar(C) },
    not_postfix_next_char,
    !,
    re_literal_run_more(Cs).

re_literal_run_more([]) --> [].

eos([], []).  % for detecting end of input

not_postfix_next_char --> call(eos)
    | (look_ahead(D), { \+ postfixchar(D) }).

postfix_next_char --> look_ahead(D), { postfixchar(D) }.

%% metachar(+Char)
metachars(".^$*+?()[]|\\{}:").
metachar(C) :-
    metachars(Cs),
    member(C, Cs).

postfixchar(D) :-
    member(D, "*+?").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 3. TOKEN-LEVEL PARSER (DCG over tokens)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_expr_tokens(AST) -->
    re_alt_tokens(AST).

re_alt_tokens(AST) -->
    re_concat_tokens(A),
    (   [pipe],
        re_alt_tokens(B),
        { AST = or(A, B) }
    ;   { AST = A }
    ).

re_concat_tokens(AST) -->
    re_atom_tokens(A),
    (   re_concat_tokens(B),
        { AST = concat(A, B) }
    ;   { AST = A }
    ).

%% Group rule
re_atom_tokens(AST) -->
    [lparen],
    group_prefix(P),
    re_expr_tokens(Sub),
    [rparen],
    { build_group_ast(P, Sub, AST) }.

re_atom_tokens(lit(Cs)) -->
    [lit(Cs)].

re_atom_tokens(escaped(C)) -->
    [escaped(C)].

re_atom_tokens(dot) -->
    [dot].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 4. GROUP PREFIXES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

group_prefix(capture) -->
    [].

group_prefix(noncapture) -->
    [question, colon].

group_prefix(lookahead) -->
    [question, '='].

group_prefix(neg_lookahead) -->
    [question, '!'].

build_group_ast(capture, Sub, capture(Sub)).
build_group_ast(noncapture, Sub, group(Sub)).
build_group_ast(lookahead, Sub, lookahead(Sub)).
build_group_ast(neg_lookahead, Sub, neg_lookahead(Sub)).
