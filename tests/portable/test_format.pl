:- use_module(library(format)).
:- use_module(library(dcgs)).
:- use_module(library(charsio)).

test :-
    Format = "~q",
    Args = ["hello"],
    (   phrase(format_(Format, Args), Chars) ->
        format("Success: ~s~n", [Chars])
    ;   format("Failure~n", [])
    ).

main :- test, halt.
