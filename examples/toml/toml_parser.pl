:- module(toml_parser, [
    parse_toml_tokens/2
]).

:- use_module(library(dcgs)).
:- use_module(library(lists)).

%% parse_toml_tokens(+Tokens, -TomlStructure)
%
% Parses a list of TOML tokens into a structured Prolog TOML AST term.
parse_toml_tokens(Tokens, toml(Entries)) :-
    phrase(toml_entries(Entries), Tokens).

toml_entries([]) --> [].
toml_entries([E|Es]) -->
    toml_entry(E),
    !,
    toml_entries(Es).

% 1. Comment
toml_entry(comment(Text)) -->
    [comment(Text)].

% 2. Table Header: [ key_path ]
toml_entry(table(Path)) -->
    [lbracket],
    key_path(Path),
    [rbracket].

% 3. Key-Value Assignment: key_path = val
toml_entry(kv(Path, Val)) -->
    key_path(Path),
    [equals],
    val(Val).

% Key path: key (. key)*
key_path([K|Ks]) -->
    key_symbol(K),
    key_path_rest(Ks).

key_path_rest([K|Ks]) -->
    [dot],
    !,
    key_symbol(K),
    key_path_rest(Ks).
key_path_rest([]) --> [].

key_symbol(K) --> [bare_key(K)].
key_symbol(K) --> [string(K)].

% Value types
val(string(S)) --> [string(S)].
val(number(N)) --> [number(N)].
val(boolean(B)) --> [boolean(B)].
val(array(Elems)) -->
    [lbracket],
    array_elems(Elems),
    [rbracket].
val(inline_table(Entries)) -->
    [lbrace],
    inline_entries(Entries),
    [rbrace].

% Array elements (comma separated)
array_elems([]) --> [].
array_elems([V|Vs]) -->
    val(V),
    array_elems_rest(Vs).

array_elems_rest([V|Vs]) -->
    [comma],
    !,
    (   val(V) -> array_elems_rest(Vs)
    ;   { Vs = [] }
    ).
array_elems_rest([]) --> [].

% Inline table entries (comma separated key-values)
inline_entries([]) --> [].
inline_entries([kv(Path, Val)|Rest]) -->
    key_path(Path),
    [equals],
    val(Val),
    inline_entries_rest(Rest).

inline_entries_rest([kv(Path, Val)|Rest]) -->
    [comma],
    !,
    (   key_path(Path), [equals], val(Val) -> inline_entries_rest(Rest)
    ;   { Rest = [] }
    ).
inline_entries_rest([]) --> [].
