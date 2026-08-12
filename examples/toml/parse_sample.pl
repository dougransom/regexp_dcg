:- module(parse_sample, [
    main/0
]).

:- use_module(library(pio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(toml_tokenizer).
:- use_module(toml_parser).

read_file_chars([]) --> [].
read_file_chars([C|Cs]) --> [C], read_file_chars(Cs).

%% main/0
%
% Reads `sample.toml` from the same directory as this file, tokenizes it using regexp_dcg,
% parses it via DCG grammar, and prints the resulting Prolog AST structure.
%
% To run this example from the command line inside the `examples/toml` directory:
%   scryer-prolog parse_sample.pl -g main
% (or: nice scryer-safe parse_sample.pl -g main)
main :-
    FilePath = "sample.toml",
    format("Reading file: ~s~n~n", [FilePath]),
    phrase_from_file(read_file_chars(Chars), FilePath),
    format("--- Raw TOML Input ---~n~s~n~n", [Chars]),
    
    format("--- 1. Tokenizing using regexp_dcg ---~n", []),
    tokenize_toml(Chars, Tokens),
    length(Tokens, NumTokens),
    format("Tokens (~d tokens generated):~n~q~n~n", [NumTokens, Tokens]),
    
    format("--- 2. Parsing into Prolog AST ---~n", []),
    parse_toml_tokens(Tokens, AST),
    format("Parsed Prolog Structure:~n~q~n~n", [AST]),
    
    format("--- 3. Pretty Printed Entries ---~n", []),
    AST = toml(Entries),
    print_entries(Entries).

print_entries([]).
print_entries([table(Path)|Es]) :-
    format_path(Path, PathStr),
    format("[Table Header] [~s]~n", [PathStr]),
    print_entries(Es).
print_entries([kv(Path, Val)|Es]) :-
    format_path(Path, PathStr),
    format("  Key: ~s => Value: ~q~n", [PathStr, Val]),
    print_entries(Es).
print_entries([comment(Text)|Es]) :-
    format("  # Comment: ~s~n", [Text]),
    print_entries(Es).

format_path([], "").
format_path([P], P).
format_path([P1, P2|Ps], PathStr) :-
    append(P1, ".", Prefix),
    format_path([P2|Ps], Rest),
    append(Prefix, Rest, PathStr).
