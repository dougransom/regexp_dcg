:- module(testing, [
    test/1,
    test/2,
    register_test/2,
    run_tests/0
]).

:- use_module(library(format)).
:- use_module(library(si)).
:- use_module(library(lists)).

:- dynamic(test_case/2).

register_test(Name, Goal) :-
    assertz(test_case(Name, Goal)).

test(Name, Goal) :-
    register_test(Name, Goal).

test(Goal) :-
    register_test(Goal, Goal).

run_tests :-
    format("=== Running Tests ===~n", []),
    findall(t(Name, Goal), test_case(Name, Goal), Tests),
    retractall(test_case(_, _)),
    run_test_list(Tests, 0, 0, Passed, Failed),
    format("=== Test Summary: ~d passed, ~d failed ===~n", [Passed, Failed]),
    (   Failed > 0 ->
        halt(1)
    ;   true
    ).

run_test_list([], P, F, P, F).
run_test_list([t(Name, Goal)|Rest], P0, F0, P, F) :-
    (   catch(user:Goal, Error, (format("FAIL (~w): ~w~n", [Name, Error]), fail)) ->
        format("OK: ~w~n", [Name]),
        P1 is P0 + 1,
        F1 = F0
    ;   format("FAIL: ~w~n", [Name]),
        P1 = P0,
        F1 is F0 + 1
    ),
    run_test_list(Rest, P1, F1, P, F).

user:term_expansion(test(Name, Goal), (:- initialization(testing:register_test(Name, Goal)))).
user:term_expansion(test(Goal), (:- initialization(testing:register_test(Goal, Goal)))).
