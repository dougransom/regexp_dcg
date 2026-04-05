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

:- dynamic(handler/2). % handler(Level, Closure)
:- dynamic(global_log_level/1).
:- dynamic(debug_on/0).

% Instrumentation that can be compiled away
debug_instrumentation(_).

user:term_expansion((:- debug_logs), (:- initialization(assertz(debug_on)))).

user:goal_expansion(debug_instrumentation(Msg), Expanded) :-
    % Expand to a runtime check so that different modules can toggle it.
    Expanded = (debug_on -> format(" [INSTRUMENTATION] ~s~n", [Msg]) ; true).

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

log(Level, Format, Args) :-
    (   should_emit(Level, _)  % the legacy semantics of -> are desired here.  If there is at least one match, lets proceed.
    ->  evaluate_lazy(Format, EvaluatedFormat),
        debug_instrumentation("Producing log entry via phrase/2"),
        % Correctly distinguish between an argument list and a single string/term arg.
        (   Args == [] -> ArgsList = []
        ;   (list_si(Args), \+ maplist(character_si, Args)) -> ArgsList = Args
        ;   ArgsList = [Args]
        ),
        maplist(evaluate_lazy, ArgsList, EvaluatedArgs),
        current_time(Time),
        (   catch(phrase(log_entry(Time, Level, EvaluatedFormat, EvaluatedArgs), FinalChars), _, fail)
        ->  emit_log(Time, FinalChars, Level),
            debug_instrumentation("Log entry emitted successfully")
        ;   phrase(format_("[~w] FORMAT_ERROR: ~q ~q\n", [Level, EvaluatedFormat, EvaluatedArgs]), ErrorChars),
            emit_log(Time, ErrorChars, Level)
        )
    ;   true
    ).

emit_log(Time, Chars, Level) :-
    (   should_emit(Level, Handler),
        call_handler(Time, Chars, Handler),
        fail
    ;   true
    ).

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
    % Ensure Format is a character list for format_//2
    { ( list_si(Format) -> FormatChars = Format ; phrase(format_("~w", [Format]), FormatChars) ) },
    format_(FormatChars, Args).

format_time(Time) -->
    { catch(get_time_val(year, Time, Y), _, Y = '??'),
      catch(get_time_val(month, Time, M), _, M = '??'),
      catch(get_time_val(day, Time, D), _, D = '??'),
      catch(get_time_val(hour, Time, H), _, H = '??'),
      catch(get_time_val(minute, Time, Min), _, Min = '??'),
      catch(get_time_val(second, Time, S), _, S = '??') },
    format_time_comp(Y), "-", format_time_comp(M), "-", format_time_comp(D), " ",
    format_time_comp(H), ":", format_time_comp(Min), ":", format_time_comp(S).

get_time_val(Key, Time, Val) :-
    (   (Key == year -> P = year(Val) ; Key == month -> P = month(Val) ; Key == day -> P = day(Val) ;
         Key == hour -> P = hour(Val) ; Key == minute -> P = minute(Val) ; Key == second -> P = second(Val)),
        member(P, Time) -> true
    ;   (Key == year -> K = 'Y' ; Key == month -> K = m ; Key == day -> K = d ;
         Key == hour -> K = 'H' ; Key == minute -> K = 'M' ; Key == second -> K = 'S'),
        member(K=Val, Time) -> true
    ;   Val = '??'
    ).

format_time_comp(V) -->
    ( { list_si(V), \+ maplist(character_si, V), V \= [] } -> format_time_list(V)
    ; { character_si(V) } -> [V]
    ; format_("~w", [V]) ).

format_time_list([]) --> [].
format_time_list([D|Ds]) --> 
    ( { integer(D) } -> format_("~w", [D])
    ; { character_si(D) } -> [D]
    ; format_("~w", [D]) ),
    format_time_list(Ds).

format_level(Level) -->
    format_("~w", [Level]).

call_handler(Time, Chars, Handler) :-
    call(Handler, Time, Chars).

% Default Handlers
console_handler(_Time, Chars) :-
    format("~s", [Chars]).

stream_handler(Stream, _Time, Chars) :-
    format(Stream, "~s", [Chars]).

% list_logger
:- dynamic(log_accumulator/1).
log_accumulator([]).

list_handler(_Time, Chars) :-
    assertz(log_accumulator(Chars)).

get_accumulated_logs(Logs) :-
    findall(C, retract(log_accumulator(C)), Chunks),
    append(Chunks, Logs).

% Lazy evaluation: if term is call(Goal, Result), call it.
evaluate_lazy(call(Goal, Result), Result) :-
    !,
    % Attempt call in current context, then user context.
    (   catch(call(Goal, Result), _, fail) -> true
    ;   catch(call(user:Goal, Result), _, fail) -> true
    ;   % Handle module-qualified goals passed as terms
        catch(Goal = M:G, _, fail), catch(call(M:G, Result), _, fail) -> true
    ;   format("Warning: Lazy evaluation goal failed: ~q~n", [Goal]),
        Result = Goal
    ).
evaluate_lazy(Result, Result).
