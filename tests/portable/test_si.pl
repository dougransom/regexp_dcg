:- use_module(library(si)).
:- use_module(library(lists)).

test :-
    (   chars_si("hello") -> format("chars_si('hello') Success~n", []) ; format("chars_si('hello') Failure~n", []) ),
    (   list_si(["hello"]) -> format("list_si(['hello']) Success~n", []) ; format("list_si(['hello']) Failure~n", []) ),
    (   maplist(chars_si, ["hello"]) -> format("maplist(chars_si, ['hello']) Success~n", []) ; format("maplist(chars_si, ['hello']) Failure~n", []) ).

main :- test, halt.
