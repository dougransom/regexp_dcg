:- use_module(library(time)).
:- use_module(library(format)).

test :-
    current_time(Time),
    format("Time: ~q~n", [Time]),
    (   Time = [year(Y), month(M), day(D), hour(H), minute(Min), second(S)|_] ->
        format("Match success: Y=~w, M=~w, D=~w, H=~w, Min=~w, S=~w~n", [Y, M, D, H, Min, S])
    ;   format("Match failure~n", [])
    ).

main :- test, halt.
