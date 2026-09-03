:- module(toml_tokenizer, [
    tokenize_toml/2
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(library(charsio)).
:- use_module('../../src/core/regexp_tree').

%% tokenize_toml(+Chars, -Tokens)
%
% Tokenizes a TOML input string into a list of TOML tokens using regexp.
tokenize_toml(Input, Tokens) :-
    phrase(tokens(Tokens), Input).

tokens([]) --> skip_ws.
tokens([T|Ts]) -->
    skip_ws,
    token(T),
    !,
    tokens(Ts).

%% skip_ws//
%
% Skips all leading whitespace (spaces, tabs, carriage returns, newlines)
% using a greedy regex matcher `\s*`.
skip_ws -->
    re_match("\\s*", _).

% 1. Comment token (#.*)
token(comment(Text)) -->
    re_match("#.*", CommentStr),
    { strip_comment_hash(CommentStr, Text) }.

% 2. Quoted String ("...")
token(string(Val)) -->
    re_match("\"[^\"]*\"", QuotedStr),
    { strip_quotes(QuotedStr, Val) }.

% 3. Float Number (-?[0-9]+\.[0-9]+)
token(number(Val)) -->
    re_match("-?[0-9]+\\.[0-9]+", NumStr),
    { number_chars(Val, NumStr) }.

% 4. Integer Number (-?[0-9]+)
token(number(Val)) -->
    re_match("-?[0-9]+", NumStr),
    { number_chars(Val, NumStr) }.

% 5. Boolean (true|false)
token(boolean(true)) -->
    re_match("true", _).
token(boolean(false)) -->
    re_match("false", _).

% 6. Bare Key ([A-Za-z0-9_-]+)
token(bare_key(Key)) -->
    re_match("[A-Za-z0-9_-]+", Key).

% 7. Punctuation
% Demonstrating regexp matching for single character literals:
% Although regexp can be used to match literal characters (e.g. re_match("\}", _)),
% pure DCG character list non-terminals (e.g. "}") are preferable when simpler.
token(equals) --> "=".
token(dot) --> ".".
token(comma) --> ",".
token(lbracket) --> "[".
token(rbracket) --> "]".
token(lbrace) --> "{".

% Demonstrate using regexp for single character literals. It would be better to just use "}" as a DCG terminal.
token(rbrace) -->
    re_match("\\}", _). 

strip_comment_hash(['#'|Rest], Rest).
strip_comment_hash([], []).

strip_quotes(['"'|Rest], Content) :-
    append(Content, ['"'], Rest),
    !.
strip_quotes(Str, Str).
