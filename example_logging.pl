:- module(example_logging, [run_examples/0, main/0,heavy_computation/1, setup_handlers/0, some_examples/0, example_lazy_a/0]).
:- use_module(logs).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(debug)).

% Enable debug instrumentation for this module
:- debug_logs.

%examples, so for guiding the development of loggers.

% A predicate that performs a "heavy" computation
heavy_computation(Result) :-
    format("Executing heavy computation...~n", []),
    Result = "Result of heavy computation".


%predicates to use in  examples


a(7) :-
    format("a(7):this should not be written to the console during log debug~n", []).

a(9) :-
    format("a(9):this should  be written to the console during log debug~n", []).

setup_handlers :-
    remove_handlers,
    add_handler(info, console_handler),
    add_handler(debug, list_handler).

example_lazy_a :-
    log_debug("This should ONLY go to list_handler (as it's debug level)"),
    a(7),
    a(9).

lazy_example1 :-
    log_info("Executing lazy example 1: ~s", [call(heavy_computation, _)]).

some_examples :-
    format("--- Example 1: Multiple Handlers ---~n", []),
    log_info("This should go to console and list_handler (as it's info level)"),
    log_debug("This should ONLY go to list_handler (as it's debug level)"),
    log_debug("This is a debug message"),
    a(7),
    a(9),
    lazy_example1,
    get_accumulated_logs(Logs),
    format("--- Accumulated Logs in list_handler ---~n~s", [Logs]),
    
    format("~n--- Example 2: Lazy evaluation once for multiple handlers ---~n", []),
    log_info("Heavy value: ~s", [call(heavy_computation, _)]),
    
    format("~n--- Example 3: Stream handler (to stderr) ---~n", []),
    add_handler(warning, stream_handler(user_error)),
    log_warning("This is a warning to stderr"),
    
    format("~n--- Example 4: Term logging ---~n", []),
    log_info(test_term(a, b, c)).

run_examples :-
    setup_handlers,
    some_examples.

main :- run_examples, halt.
