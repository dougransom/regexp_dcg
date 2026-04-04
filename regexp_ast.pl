% This module provides a DCG-based parser for regular expressions, matching those of Python 3.14 Regexp.
:- module(regexp_ast, [
 
    re_token//1,
    re_tokens//1,
    re_ast//1,
    re_ast_chars//1,
    re_literal_run//1,
    re_literal_run_recognize//1,
    metachar/1,
    metachars/1,
    re_expr_tokens//1,
    posix_name//1,
    class_item//1
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

% Reusable expansion to turn a string into O(1) facts for a predicate.
user:term_expansion(generate_char_predicate(Name, String), [PluralFact|Clauses]) :-
    atom_concat(Name, s, PluralName),
    PluralFact =.. [PluralName, String],
    findall(Head, (
        member(Char, String),
        Head =.. [Name, Char]
    ), Clauses).

user:term_expansion(tk(Term, String), (re_token(Term) --> String, !)).
user:term_expansion(ci(Term, String), (class_item(Term) --> String, !)).


%:- dynamic metachars/1.

%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1. TOP-LEVEL: tokenize → token-level DCG parser
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  AST PARSER (Phase 1D)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Entry point
re_ast(AST) -->
    re_alt(AST).

% Convenience interface: tokenize chars and build AST in one step
re_ast_chars(AST) -->
    re_tokens(Tokens),
    { phrase(re_expr_tokens(AST), Tokens) }.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Alternation: A | B | C
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_alt(AST) -->
    re_concat(L0),
    (   [pipe],
        re_alt(R0),
        { AST1 = alt(L0, R0) }
    ;   { AST1 = L0 }
    ),
    { normalize_concat(AST1, AST) }.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Concatenation: implicit adjacency
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Concatenation: implicit adjacency
%
% Important: we ONLY build concat/1 when there are 2+ factors.
% A single factor is returned as-is.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_concat(AST) -->
    re_factor(F),
    re_concat_more(F, AST0),
    {
        ( AST0 = concat([Single]) ->
            AST = Single
        ;   AST = AST0
        )
    }.

re_concat_more(Acc, AST) -->
    re_factor(F),
    !,
    {
        ( Acc = concat(List0) ->
            append(List0, [F], List)
        ;   List = [Acc, F]
        ),
        Acc1 = concat(List)
    },
    re_concat_more(Acc1, AST).

re_concat_more(Acc, Acc) -->
    [].

normalize_concat(concat([X]), X) :- !.
normalize_concat(X, X).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Postfix operators: *, +, ?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_factor(Node) -->
    re_atom(A),
    (   [star],  { Node = star(A) }
    ;   [plus],  { Node = plus(A) }
    ;   [qmark], { Node = maybe(A) }
    ;   { Node = A }
    ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Atoms: groups, classes, anchors, boundaries, literals
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_atom(group(A)) -->
    [lparen],
    re_alt(A),
    [rparen].

re_atom(class(Items)) -->
    [class(Items)].

re_atom(anchor(bol)) -->
    [caret].

re_atom(anchor(eol)) -->
    [dollar].

re_atom(boundary(word)) -->
    [boundary(word)].

re_atom(boundary(not_word)) -->
    [boundary(not_word)].

re_atom(lit(S)) -->
    [lit(S)].


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2. re_tokenIZER (DCG, deterministic, greedy)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

re_tokens([T|Ts]) --> re_token(T), !, re_tokens(Ts).
re_tokens([])     --> [].

%% re_token(-Tok)
%% re_token(-Tok) / re_token(+Tok)

% escaped should be first

tk(boundary(word),     "\\b").
tk(boundary(not_word), "\\B").

tk(builtin(digit),      "\\d").
tk(builtin(not_digit),  "\\D").
tk(builtin(word),       "\\w").
tk(builtin(not_word),   "\\W").
tk(builtin(space),      "\\s").
tk(builtin(not_space),  "\\S").


% character class (must come before lbrack/rbrack)
re_token(class(Items)) -->
    "[",
    class_items(Items),
    "]",
    !.

re_token(lit(Cs)) -->
    { var(Cs) },                 % tokenizing
    re_literal_run_recognize(Cs), !.

re_token(lit(Cs)) -->
    { nonvar(Cs) },              % generating
    re_literal_run(Cs), !.

re_token(escaped(C)) -->
    "\\", [C], !.

tk(dot,      ".").
tk(caret,    "^").
tk(dollar,   "$").
tk(lparen,   "(").
tk(rparen,   ")").
tk(lbrack,   "[").
tk(rbrack,   "]").
tk(pipe,     "|").
tk(star,     "*").
tk(plus,     "+").
tk(question, "?").
tk(lbrace,   "{").
tk(rbrace,   "}").
tk(colon,    ":").
tk(comma,    ",").


look_ahead(T), [T] --> [T].


class_items(Items) -->
    "^", !,
    class_items_rest(Rest),
    { Items = neg(Rest) }.

class_items(Items) -->
    class_items_rest(Items).

class_items_rest([Item|Items]) -->
    class_item(Item),
    class_items_rest(Items).

class_items_rest([]) --> [].

%order matters for class item
ci(builtin(digit),      "\\d").
ci(builtin(not_digit),  "\\D").

ci(builtin(word),       "\\w").
ci(builtin(not_word),   "\\W").

ci(builtin(space),      "\\s").
ci(builtin(not_space),  "\\S").

class_item(posix(Name)) -->
    "[:",
    posix_name(Name),
    ":]".

class_item(range(A,B)) -->
    class_char(A),
    "-",
    class_char(B), !.

class_item(char(C)) -->
    class_char(C).

posix_name(Name) -->
    posix_name_chars(Cs),
    { atom_chars(Name, Cs) }.

posix_name_chars([C|Cs]) -->
    [C],
    { C \= 0': }, 
    posix_name_chars(Cs).

posix_name_chars([]) -->
    [].






class_char(C) -->
    "\\", [C], !.     % escaped char

class_char(C) -->
    [C],
    { C \= 0'] }.      % don't allow ']' inside


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

%% Define metacharacters and postfix characters using the expansion mechanism.
generate_char_predicate(metachar, ".^$*+?()[]|\\{}:,").
generate_char_predicate(postfixchar, "*+?").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 3. TOKEN-LEVEL PARSER (DCG over tokens)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
re_expr_tokens(anchor(bol)) -->
    [caret].

re_expr_tokens(anchor(eol)) -->
    [dollar].

re_expr_tokens(boundary(word)) -->
    [boundary(word)].

re_expr_tokens(boundary(not_word)) -->
    [boundary(not_word)].

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
    re_postfix_tokens(A),
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

%% Classes
re_atom_tokens(class(Items)) -->
    [class(Items)].


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



%%% Quantifiers
quantifier(mn(M,N)) -->
    [lbrace],
    integer_token(M),
    (   [comma], integer_token(N)
    ;   [comma], { N = inf }
    ;   { N = M }
    ),
    [rbrace].

integer_token(N) -->
    [lit(Cs)],
    { number_chars(N, Cs) }.

%%% Postfix Operators

postfix_op(star)     --> [star].
postfix_op(plus)     --> [plus].
postfix_op(question) --> [question].

re_postfix_tokens(AST) -->
    re_atom_tokens(A),
    (   postfix_op(Op),
        { AST = postfix(A, Op) }
    ;   quantifier(Q),
        { AST = quant(A, Q) }
    ;   { AST = A }
    ).
