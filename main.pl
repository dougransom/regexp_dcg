% Loads the package loader
:- use_module(bakage).

% Loads a package. The argument should be an atom equal to the name of the
% dependency package specified in the `name/1` field of its manifest.
:- use_module(pkg(testing)).

% You can then use the predicates exported by the main file of the dependency
% in the rest of the program.

main :-
    % `run_tests/0` is exported by `pkg(testing)`
    run_tests,
    halt.

test("Example test", (true)).
test("Another test", (false)).