:- module(example_logging, [run_examples/0, heavy_computation/1]).
:- use_module(logs).
:- use_module(library(format)).
:- use_module(library(lists)).

% A predicate that performs a "heavy" computation
heavy_computation(Result) :-
    format("Executing heavy computation...~n", []),
    Result = "Result of heavy computation".

run_examples :-
    remove_handlers,
    add_handler(info, console_handler),
    add_handler(debug, list_handler),

    format("--- Example 1: Multiple Handlers ---~n", []),
    log_info("This should go to console and list_handler (as it's info level)"),
    log_debug("This should ONLY go to list_handler (as it's debug level)"),
    
    get_accumulated_logs(Logs),
    format("--- Accumulated Logs in list_handler ---~n~s", [Logs]),
    
    format("~n--- Example 2: Lazy evaluation once for multiple handlers ---~n", []),
    log_info("Heavy value: ~s", [call(heavy_computation, _)]),
    
    format("~n--- Example 3: Stream handler (to stderr) ---~n", []),
    add_handler(warning, stream_handler(user_error)),
    log_warning("This is a warning to stderr"),
    
    format("~n--- Example 4: Term logging ---~n", []),
    log_info(test_term(a, b, c)).

main :- run_examples, halt.
