:- module(logs, [
    log/2,
    log/3,
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
    console_handler/1,
    stream_handler/2,
    list_handler/1
]).

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(time)).
:- use_module(library(iso_ext)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(reif)).

:- dynamic(handler/2). % handler(Level, Closure)
:- dynamic(global_log_level/1).

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

% log_debug/1, log_info/1, etc. - logs a single term
log_debug(Term)    :- log(debug, "~q", [Term]).
log_info(Term)     :- log(info, "~q", [Term]).
log_warning(Term)  :- log(warning, "~q", [Term]).
log_error(Term)    :- log(error, "~q", [Term]).
log_critical(Term) :- log(critical, "~q", [Term]).

% log_debug/2, log_info/2, etc. - logs a format string and arguments
log_debug(Format, Args)    :- log(debug, Format, Args).
log_info(Format, Args)     :- log(info, Format, Args).
log_warning(Format, Args)  :- log(warning, Format, Args).
log_error(Format, Args)    :- log(error, Format, Args).
log_critical(Format, Args) :- log(critical, Format, Args).

log(Level, Format) :-
    log(Level, Format, []).

log(Level, Format, Args) :-
    % Evaluate lazy message once for all handlers
    evaluate_lazy(Format, EvaluatedFormat),
    (   atom(Args) -> ArgsList = [Args]
    ;   ArgsList = Args
    ),
    maplist(evaluate_lazy, ArgsList, EvaluatedArgs),
    % Get system time once per log event
    current_time(Time),
    % Format the message once
    (   phrase(log_entry(Time, Level, EvaluatedFormat, EvaluatedArgs), FinalChars)
    ->  emit_log(FinalChars, Level)
    ;   phrase(format_("[~w] FORMAT_ERROR: ~q ~q\n", [Level, EvaluatedFormat, EvaluatedArgs]), ErrorChars),
        emit_log(ErrorChars, Level)
    ).

emit_log(Chars, Level) :-
    should_emit(Level, Handler),
    call_handler(Chars, Handler),
    fail.
emit_log(_, _).

should_emit(Level, Handler) :-
    handler(HandlerLevel, Handler),
    level_weight(Level, Weight),
    level_weight(HandlerLevel, HandlerWeight),
    Weight >= HandlerWeight.

log_entry(Time, Level, Format, Args) -->
    "[", format_time(Time), "] ",
    "[", format_level(Level), "] ",
    log_format(Format, Args),
    "\n".

log_format(Format, Args) -->
    format_(Format, Args).
log_format(Format, Args) -->
    {   \+ atom(Format) },
    { phrase(format_("~q", [Format]), FormatChars) },
    FormatChars,
    " ",
    { phrase(format_("~q", [Args]), ArgsChars) },
    ArgsChars.

format_time(Time) -->
    { member('Y'=Y, Time),
      member(m=M, Time),
      member(d=D, Time),
      member('H'=H, Time),
      member('M'=Min, Time),
      member('S'=S, Time),
      phrase(format_("~s-~s-~s ~s:~s:~s", [Y, M, D, H, Min, S]), Chars) },
    Chars.

format_level(Level) -->
    { phrase(format_("~w", [Level]), Chars) },
    Chars.

call_handler(Chars, Handler) :-
    call(Handler, Chars).

% Default Handlers
console_handler(Chars) :-
    format("~s", [Chars]).

stream_handler(Stream, Chars) :-
    format(Stream, "~s", [Chars]).

% list_logger
:- dynamic(log_accumulator/1).
log_accumulator([]).

list_handler(Chars) :-
    retract(log_accumulator(Old)),
    append(Old, Chars, New),
    asserta(log_accumulator(New)).

get_accumulated_logs(Logs) :-
    log_accumulator(Logs).

% Lazy evaluation: if term is call(Goal, Result), call it.
evaluate_lazy(call(Goal, Result), Result) :-
    !,
    (   (functor(Goal, Name, Arity), current_predicate(Name/Arity)) ->
        call(Goal, Result)
    ;   format("Warning: Lazy evaluation goal not found: ~q~n", [Goal]),
        Result = Goal
    ).
evaluate_lazy(Result, Result).

