/**
  ### Purpose of the `logs` Module

  The `logs` module provides a flexible, multi-handler logging and instrumentation framework for ISO Prolog.
  It supports level-filtered log emission (`debug`, `info`, `warning`, `error`, `critical`),
  pluggable log handlers (console, stream/file, in-memory list), and compile-time goal expansion
  for zero-overhead debug instrumentation.

  ---

  ### Usage Examples

  #### 1. Basic Logging
  ```prolog
  :- use_module(logs).

  example :-
      log_info("Application started with count: ~d", [42]),
      log_warning("High memory usage detected"),
      log_error("Failed to parse pattern ~s", ["a**"]).
  ```

  #### 2. Registering Log Handlers
  By default, log messages are dispatched to registered handlers:
  - `add_handler(console_handler)`: Prints formatted logs to stdout.
  - `add_handler(list_handler)`: Stores log terms in memory; retrieve via `get_accumulated_logs(Logs)`.
  - `add_handler(stream_handler(Stream))`: Writes log output to a file/stream.
  - `remove_handlers`: Clears all registered handlers.

  #### 3. Filtering Log Levels
  - `set_log_level(debug)` — Enable all log messages down to debug.
  - `set_log_level(info)`  — Default level (suppresses debug).
  - `set_log_level(error)` — Suppress debug, info, and warning logs.

  ---

  ### Enabling & Disabling Debug Instrumentation (`debug_instrumentation`)

  The module provides `debug_instrumentation(Format, Args)` goals that can be embedded throughout performance-sensitive code.

  #### How to Enable:
  1. **Compile-time directive**: Add `:- debug_logs.` at the top of your file.
  2. **Runtime assertion**: Call `assertz(logs:debug_on).` before running goals.

  #### How to Disable:
  1. **Omit directive**: If `:- debug_logs.` is omitted and `logs:debug_on` is not asserted, `debug_instrumentation/2` automatically expands to `true` during macro expansion, incurring **zero runtime performance penalty**.
  2. **Runtime retract**: Call `retractall(logs:debug_on).` to disable dynamic instrumentation.
*/
:- module(logs, [
    log/2,
    log/3,
    log_f/3,
    log_s/3,
    log_debug/1,
    log_debug/2,
    log_info/1,
    log_info/2,
    log_warning/1,
    log_warning/2,
    log_error/1,
    log_error/2,
    log_critical/1,
    log_critical/2,
    add_handler/1,
    add_handler/2,
    remove_handlers/0,
    set_log_level/1,
    get_log_level/1,
    get_accumulated_logs/1,
    console_handler/2,
    stream_handler/3,
    list_handler/2
]).

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(time)).
:- use_module(library(iso_ext)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(reif)).
:- use_module(library(freeze)).
:- use_module(library(cont)).
:- use_module(library(error)).

:- dynamic(handler/2). % handler(Level, Closure)
:- dynamic(global_log_level/1).
:- dynamic(debug_on/0).

% Instrumentation that can be compiled away
debug_instrumentation(_) :- true.
debug_instrumentation(_, _) :- true.

user:term_expansion((:- debug_logs), (:- initialization(assertz(logs:debug_on)))).

user:goal_expansion(debug_instrumentation(Fmt, Args), Expanded) :-
    Expanded = (catch(logs:debug_on, _, fail) -> (format(" [INSTRUMENTATION] ", []), format(Fmt, Args), nl) ; true).

user:goal_expansion(debug_instrumentation(Msg), Expanded) :-
    Expanded = (catch(logs:debug_on, _, fail) -> format(" [INSTRUMENTATION] ~s~n", [Msg]) ; true).

% Goal expansion to optimize calls to log_Level/1 and log_Level/2 at the call site.
user:goal_expansion(Call, log(Level, Format, Args)) :-
    nonvar(Call),
    functor(Call, Name, Arity),
    atom_concat(log_, Level, Name),
    level_weight(Level, _),
    (   Arity =:= 1 -> arg(1, Call, T), Format = "~w", Args = [T]
    ;   Arity =:= 2 -> arg(1, Call, Format), arg(2, Call, Args)
    ).

% Term expansion to generate the log_Level predicates automatically within this module.
term_expansion(generate_log_predicates, Clauses) :-
    findall(Clause, (
        level_weight(Level, _),
        atom_concat(log_, Level, Name),
        (   Clause = (Head1 :- log(Level, "~q", [Term])), Head1 =.. [Name, Term]
        ;   Clause = (Head2 :- log(Level, Format, Args)), Head2 =.. [Name, Format, Args]
        )
    ), Clauses).

% Log levels inspired by Python
level_weight(debug, 10).
level_weight(info, 20).
level_weight(warning, 30).
level_weight(error, 40).
level_weight(critical, 50).

% Default configuration
global_log_level(info).

% Initialize with a default console handler if none exist
:- initialization(setup_default_handlers).

setup_default_handlers :-
    (   handler(_, _) -> true
    ;   add_handler(info, console_handler)
    ).

set_log_level(Level) :-
    must_be_valid_level(Level),
    retractall(global_log_level(_)),
    asserta(global_log_level(Level)).

get_log_level(Level) :-
    global_log_level(Level).

must_be_valid_level(Level) :-
    (   level_weight(Level, _) -> true
    ;   domain_error(log_level, Level)
    ).

add_handler(Handler) :-
    global_log_level(Level),
    add_handler(Level, Handler).

add_handler(Level, Handler) :-
    must_be_valid_level(Level),
    assertz(handler(Level, Handler)).

remove_handlers :-
    retractall(handler(_, _)).

% Generate the log_Level/1 and log_Level/2 predicates automatically
generate_log_predicates.

log(Level, Format) :-
    log(Level, Format, []).

log(A,B,C) :- debug_instrumentation("Calling log_f", []), log_f(A,B,C). 

log_f(Level, Format, Args) :-
    debug_instrumentation("Setting up log_f (lazy) for Level: ~w", [Level]),
    % Chars is a shared logic variable. The first handler to access it
    % triggers the calculation; others use the cached result.
    % current_time is moved inside to ensure perfect laziness.
    freeze(Chars, (
        catch((
            evaluate_lazy(Format, EvalF),
            (   Args == [] -> AL = []
            ;   (list_si(Args), \+ maplist(character_si, Args)) -> AL = Args
            ;   AL = [Args]
            ),
            maplist(evaluate_lazy, AL, EvalA),
            (   phrase(log_entry(Level, EvalF, EvalA), Chars)
            ->  true
            ;   Chars = "FORMAT_ERROR: phrase/2 failed\n"
            )
        ), E, (phrase(format_("ERROR IN FREEZE (~w): ~q\n", [Level, E]), Chars)))
    )),
    debug_instrumentation("log_f: Chars variable created, calling emit_log"),
    current_time(Time),
    emit_log(Level, Chars, Time).

log_s(Level, Format, Args) :-
    debug_instrumentation("log_s: executing eagerly"),
    reset(prepare_chars_s(Level, Format, Args), Chars, _),
    current_time(Time),
    emit_log(Level, Chars, Time).

% Helper for log_s: computes the string and yields it back to the reset point.
prepare_chars_s(Level, Format, Args) :-
    debug_instrumentation("Inside shift helper for Level: ~w", [Level]),
    evaluate_lazy(Format, EvalF),
    (   Args == [] -> AL = []
    ;   (list_si(Args), \+ maplist(character_si, Args)) -> AL = Args
    ;   AL = [Args]
    ),
    maplist(evaluate_lazy, AL, EvalA),
    (   phrase(log_entry(Level, EvalF, EvalA), Chars)
    ->  shift(Chars)
    ;   shift("FORMAT_ERROR\n")
    ).

emit_log(Level, Chars, Time) :-
    debug_instrumentation("emit_log: checking handlers for Level: ~w at ~w", [Level, Time]),
    (   should_emit(Level, Handler),
        debug_instrumentation("emit_log: found handler ~w", [Handler]),
        call_handler(Time, Chars, Handler),
        fail
    ;   true
    ).

should_emit(Level, Handler) :-
    nonvar(Level),
    handler(HandlerLevel, Handler),
    level_weight(Level, Weight),
    level_weight(HandlerLevel, HandlerWeight),
    Weight >= HandlerWeight.

log_entry(Level, Format, Args) -->
    "[", format_level(Level), "] ",
    log_format(Format, Args),
    "\n".

log_format(Format, Args) -->
    % Ensure Format is a character list for format_//2
    { ( list_si(Format) -> FormatChars = Format ; phrase(format_("~w", [Format]), FormatChars) ) },
    format_(FormatChars, Args).

format_level(Level) -->
    format_("~w", [Level]).

call_handler(Time, Chars, Handler) :-
    call(Handler, Time, Chars).

% Default Handlers
console_handler(_Time, Chars) :-
    debug_instrumentation("console_handler: writing chars"),
    write_chars(Chars).

stream_handler(Stream, _Time, Chars) :-
    debug_instrumentation("stream_handler: writing to ~w", [Stream]),
    write_chars(Stream, Chars).

write_chars(Chars) :- write_chars(user_output, Chars).
write_chars(Stream, Chars) :-
    (   var(Chars) -> 
        % Unification triggers the freeze/2 goal.
        ( Chars = [C|Cs] -> put_char(Stream, C), write_chars(Stream, Cs) ; true )
    ;   Chars = [] -> true
    ;   Chars = [C|Cs] -> put_char(Stream, C), write_chars(Stream, Cs)
    ;   % Fallback for non-list terms
        format(Stream, "~w", [Chars])
    ).

% list_logger
:- dynamic(log_accumulator/1).

list_handler(_Time, Chars) :-
    debug_instrumentation("list_handler: accumulating chars"),
    assertz(log_accumulator(Chars)).

get_accumulated_logs(Logs) :-
    findall(C, retract(log_accumulator(C)), Chunks),
    append(Chunks, Logs).

% Lazy evaluation: if term is call(Goal, Result), call it.
evaluate_lazy(call(Goal, Result), Out) :-
    !,
    % Attempt call in current context, then user context.
    (   (catch(call(Goal, Result), _, fail), nonvar(Result)) -> Out = Result
    ;   (catch(call(user:Goal, Result), _, fail), nonvar(Result)) -> Out = Result
    ;   % Handle module-qualified goals passed as terms
        (nonvar(Goal), Goal = M:G) -> (catch(call(M:G, Result), _, phrase(format_("ERR(~q)", [Goal]), Out)))
    ;   % If evaluation fails, instantiate Result to an error string
        % to avoid instantiation errors in format (~s).
        phrase(format_("ERR(~q)", [Goal]), Out)
    ).
evaluate_lazy(Result, Out) :-
    (   var(Result) -> phrase(format_("~w", [Result]), Out)
    ;   Out = Result
    ).
