:- use_module(library(time)).
:- use_module(library(format)).

test :-
    now(Time),
    format("Time: ~q~n", [Time]),
    (   integer(Time), Time > 0 ->
        format("Match success: Epoch=~w~n", [Time])
    ;   format("Match failure~n", [])
    ).

main :- test, halt.
