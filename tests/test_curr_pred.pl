:- module(test_mod, [test_pred/1]).
test_pred(x).

:- use_module(library(format)).

test :-
    (   current_predicate(test_mod:test_pred/1) -> format("Qualified Success~n", []) ; format("Qualified Failure~n", []) ),
    (   current_predicate(test_pred/1) -> format("Unqualified Success~n", []) ; format("Unqualified Failure~n", []) ).

main :- test, halt.
