:- use_module(library(time)).
:- use_module(library(format)).

:- use_module(library(lists)).

test :-
    current_time(Time),
    format("Time: ~q~n", [Time]),
    (   member('Y'=Y, Time),
        member(m=M, Time),
        member(d=D, Time),
        member('H'=H, Time),
        member('M'=Min, Time),
        member('S'=S, Time) ->
        format("Match success: Y=~w, M=~w, D=~w, H=~w, Min=~w, S=~w~n", [Y, M, D, H, Min, S])
    ;   format("Match failure~n", [])
    ).

main :- test, halt.
