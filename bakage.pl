/*usr/bin/env true

set -eu

type scryer-prolog > /dev/null 2> /dev/null \
    && exec scryer-prolog -f -g "bakage:run" "$0" -- "$@"

echo "No known supported Prolog implementation available in PATH."
echo "Try to install Scryer Prolog."
exit 1
#*/

/* SPDX-License-Identifier: Unlicense */

:- module(bakage, [pkg_install/1]).

% ==========================
% === Compatibility zone ===
% ==========================

% Everything that is implementation specific, implementation defined, or otherwise not guaranteed
% by the base 13211-1 ISO standard with corrigenda should be encapsulated here so that we only
% have to look in one place when porting or making this more portable.

% Hard to shim

:- use_module(library(os), [argv/1, setenv/2, shell/1, unsetenv/1, getenv/2]).
:- use_module(library(files), [
    directory_exists/1, make_directory_path/1, directory_files/2, file_exists/1,
    delete_file/1, delete_directory/1, working_directory/2
]).
:- use_module(library(dcgs), [phrase/2, phrase/3, ... //0]). % 13211-3
:- use_module(library(charsio), [write_term_to_chars/3]).
:- use_module(library(iso_ext), [setup_call_cleanup/3, call_cleanup/2]).

% Easy to shim
:- use_module(library(lists), [
    length/2, maplist/1, member/2, append/2, maplist/2, append/3, memberchk/2
]).
:- use_module(library(pio), [phrase_to_file/2, phrase_to_stream/2]).
:- use_module(library(dif), [dif/2]). % With dif_si/2, though that may lose some functionality
:- use_module(library(reif), [if_/3, (;)/3, memberd_t/3, (=)/3]).
:- use_module(library(format), [portray_clause/1, portray_clause_//1]).

user:term_expansion((:- use_module(pkg(Package))), (:- use_module(PackageMainFile))) :-
    package_main_file(Package, PackageMainFile).

% =================================
% === End of compatibility zone ===
% =================================


% Cleanly pass arguments to a script through environment variables
run_script_with_args(ScriptName, Args, Success) :-
    maplist(define_script_arg, Args),
    append(["sh scryer_libs/scripts/", ScriptName, ".sh"], Script),
    (
        shell(Script) ->
            Success = true
        ;   Success = false
    ),
    maplist(undefine_script_arg, Args).

define_script_arg(Arg-Value) :- setenv(Arg, Value).
undefine_script_arg(Arg-_) :- unsetenv(Arg).

% join_sep_split/3: Monotonic join and split by separator.
% Implementation by @bakaq from https://github.com/mthom/scryer-prolog/discussions/3121
%
% True when `Joined` is a list consisting of all the lists in `Segments`
% separated by `Separator`, and `Separator` doesn't appear in any of the
% lists in `Segments`. Can be used as both a split and a join depending
% on the mode.
join_sep_split(Joined, Separator, Segments) :-
    join_sep_split_(Separator, Joined, Segments).

% The empty separator case is just append/2
join_sep_split_([], Joined, Segments) :-
    append(Segments, Joined).
join_sep_split_([S|Ss], Joined, Segments) :-
    join_sep_split(Joined, [], [S|Ss], Segments, []).

% Stuff like this that needs 2 list differences is hard to encode
% in a DCG in my experience.
join_sep_split([], [], _, [], []).
join_sep_split([L0|LT0], Ls, Sep, [Seg|Segs0], Segs) :-
    Ls0 = [L0|LT0],
    next_segment(Ls0, Seg, Sep, Ls1, Reason),
    join_sep_split_(Ls1, Ls, Sep, Segs0, Segs, Reason).

join_sep_split_([], [], _, Segs0, Segs, Reason) :-
    reason_segs(Reason, Segs0, Segs).
join_sep_split_([L0|LT0], Ls, Sep, Segs0, Segs, _) :-
    join_sep_split([L0|LT0], Ls, Sep, Segs0, Segs).

reason_segs(sep, [[]|Segs], Segs).
reason_segs(end, Segs, Segs).

next_segment([], [], _, [], end).
next_segment([L0|Ls0], Seg, Sep, Ls, Reason) :-
    if_(
        starts_with_t(Sep, [L0|Ls0], Ls1),
        (Ls = Ls1, Seg = [], Reason = sep),
        (Seg = [L0|Seg1], next_segment(Ls0, Seg1, Sep, Ls, Reason))
    ).

starts_with_t([], Ls, Ls, true).
starts_with_t([S|Ss], Ls0, Ls, T) :-
    starts_with_t_(Ls0, Ls, S, Ss, T).

starts_with_t_([], _, _, _, false).
starts_with_t_([L|Ls0], Ls, S, Ss, T) :-
    if_(
        S = L,
        starts_with_t(Ss, Ls0, Ls, T),
        T = false
    ).

find_project_root(Root) :-
    working_directory(CWD, CWD),
    find_project_root_from(CWD, Root).

find_project_root_from(Dir, Root) :-
    append(Dir, "/scryer-manifest.pl", ManifestPath),
    (   file_exists(ManifestPath) ->
        Root = Dir
    ;   join_sep_split(Dir, "/", Segments),
        append(ParentSegments, [_LastSegment], Segments),
        ParentSegments \= [],
        join_sep_split(ParentDir, "/", ParentSegments),
        find_project_root_from(ParentDir, Root)
    ).

scryer_path(ScryerPath) :-
    (   getenv("SCRYER_PATH", EnvPath) ->
        ScryerPath = EnvPath
    ;   find_project_root(RootChars),
        append([RootChars, "/scryer_libs"], ScryerPath)
    ).


% A prolog file knowledge base represented as a list of terms
prolog_kb_list(Stream) --> {read(Stream, Term), dif(Term, end_of_file)}, [Term], prolog_kb_list(Stream).
prolog_kb_list(Stream) --> {read(Stream, Term), Term == end_of_file}, [].

parse_manifest(Filename, Manifest) :-
    setup_call_cleanup(
        open(Filename, read, Stream),
        catch(once(phrase(prolog_kb_list(Stream), Manifest)), error(E, I), throw(error_formating_of_manifest(E, I))),
        close(Stream)
    ).

package_main_file(Package, PackageMainFile) :-
    atom_chars(Package, PackageChars),
    scryer_path(ScryerPath),
    append([ScryerPath, "/packages/", PackageChars], PackagePath),
    append([PackagePath, "/", "scryer-manifest.pl"], ManifestPath),
    parse_manifest(ManifestPath, Manifest),
    member(main_file(MainFile), Manifest),
    append([PackagePath, "/", MainFile], PackageMainFileChars),
    atom_chars(PackageMainFile, PackageMainFileChars).

% This creates the directory structure we want
ensure_scryer_libs :-
    (   directory_exists("scryer_libs") ->
        true
    ;   make_directory_path("scryer_libs")
    ),
    (   directory_exists("scryer_libs/packages") ->
        true
    ;   make_directory_path("scryer_libs/packages")
    ),
    (   directory_exists("scryer_libs/scripts") ->
        true
    ;   make_directory_path("scryer_libs/scripts"),
        ensure_scripts
    ),
    (   directory_exists("scryer_libs/temp") ->
        true
    ;   make_directory_path("scryer_libs/temp")
    ).

% Installs helper scripts
ensure_scripts :-
    findall(ScriptName-ScriptString, script_string(ScriptName, ScriptString), Scripts),
    maplist(ensure_script, Scripts).

ensure_script(Name-String) :-
    append(["scryer_libs/scripts/", Name, ".sh"], Path),
    phrase_to_file(String, Path).


% Predicate to install the dependencies
pkg_install(Report) :-
        parse_manifest("scryer-manifest.pl", Manifest),
        ensure_scryer_libs,
        setenv("SHELL", "/bin/sh"),
        setenv("GIT_ADVICE", "0"),
        directory_files("scryer_libs/packages", Installed_Packages),
        if_(valid_manifest_t(Manifest, Validation_Report),
            (member(dependencies(Deps), Manifest) ->
                call_cleanup(
                    (
                    logical_plan(Plan, Deps, Installed_Packages),
                    installation_execution(Plan, Installation_Report),
                    append(Validation_Report, Installation_Report, Report)
                    ),
                    delete_directory("scryer_libs/temp")
                ) ; Report = Validation_Report
            ),
            Report = Validation_Report
        ).

% A logical plan to install the dependencies
logical_plan(Plan, Ds, Installed_Packages) :-
    phrase(fetch_plan(Ds, Installed_Packages), Plan).

% A logical plan to fetch the dependencies
fetch_plan([], _) --> [].
fetch_plan([D|Ds], Installed_Packages) -->
    {fetch_step(D, Installation_Step, Installed_Packages)},
    [Installation_Step],
    fetch_plan(Ds, Installed_Packages).


% A step of a logical plan to fetch the dependencies
fetch_step(dependency(Name, DependencyTerm), Step, Installed_Packages) :-
    if_(memberd_t(Name, Installed_Packages),
        Step = do_nothing(dependency(Name, DependencyTerm)),
        Step = install_dependency(dependency(Name, DependencyTerm))
    ).

% Execute the physical installation of the dependencies
installation_execution(Plan, Results):-
    ensure_dependencies(Plan, Success),
    if_(Success = false,
        phrase(fail_installation(Plan), Results),
        true
    ),
    parse_install_report(Result_Report),
    phrase(installation_report(Plan, Result_Report), Results).

% All dependency installation failed
fail_installation([]) --> [].
fail_installation([P|Ps]) --> [P-error("installation script failed")], fail_installation(Ps).


% Parse the report of the installation of the dependencies
parse_install_report(Result_List) :-
    setup_call_cleanup(
        open("scryer_libs/temp/install_resp.pl", read, Stream),
        once(phrase(prolog_kb_list(Stream), Result_List)),
        (
            close(Stream),
            ( file_exists("scryer_libs/temp/install_resp.pl")->
                delete_file("scryer_libs/temp/install_resp.pl")
            ; true
            )
        )
    ).

% The installation report of the dependencies
installation_report([], _) --> [].
installation_report([P|Ps], Result_Report) -->
    { report_installation_step(P, Result_Report, R) },
    [R],
    installation_report(Ps, Result_Report).

% The result of a logical step
report_installation_step(do_nothing(dependency(Name, DependencyTerm)), _, do_nothing(dependency(Name, DependencyTerm))-success).


report_installation_step(install_dependency(dependency(Name, DependencyTerm)), ResultMessages, install_dependency(dependency(Name, DependencyTerm))-Message):-
    memberchk(result(Name, Message), ResultMessages).

% Execute the logical plan
ensure_dependencies(Logical_Plan, Success) :-
    phrase(physical_plan(Logical_Plan), Physical_Plan),
    Args = [
        "DEPENDENCIES_STRING"-Physical_Plan
    ],
    run_script_with_args("ensure_dependencies", Args, Success).


% Create a physical plan in shell script
physical_plan([]) --> [].
physical_plan([P|Ps]) --> physical_plan_([P|Ps]).

physical_plan_([P]) --> {
    physical_plan_step(P, El)
    },
    El.

physical_plan_([P|Ps]) --> {
    physical_plan_step(P, El)
    },
    El,
    "|",
    physical_plan_(Ps).

% Create a step for the shell script physical plan
physical_plan_step(do_nothing(dependency(Name, D)) , El) :-
    write_term_to_chars(D, [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=do_nothing"], El).

physical_plan_step(install_dependency(dependency(Name, git(Url))) ,El):-
    write_term_to_chars(git(Url), [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=git_default;git_url=", Url], El).

physical_plan_step(install_dependency(dependency(Name, git(Url,branch(Branch)))) ,El):-
    write_term_to_chars(git(Url,branch(Branch)), [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=git_branch;git_url=", Url, ";git_branch=", Branch], El).

physical_plan_step(install_dependency(dependency(Name, git(Url,tag(Tag)))) ,El):-
    write_term_to_chars(git(Url,tag(Tag)), [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=git_tag;git_url=", Url, ";git_tag=", Tag], El).

physical_plan_step(install_dependency(dependency(Name, git(Url,hash(Hash)))) ,El):-
    write_term_to_chars(git(Url,hash(Hash)), [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=git_hash;git_url=", Url, ";git_hash=", Hash], El).

physical_plan_step(install_dependency(dependency(Name, path(Path))) ,El):-
    write_term_to_chars(path(Path), [quoted(true), double_quotes(true)], DependencyTermChars),
    append(["dependency_term=", DependencyTermChars, ";dependency_name=", Name, ";dependency_kind=path;dependency_path=", Path], El).

% Qupak: Pattern Matching for library(reif)
%
% === Bibliographic Note ===
% Author: Kauê Hunnicutt Bazilli (https://github.com/bakaq)
% Original implementation: https://github.com/bakaq/qupak
%   Git Commit Hash: 5ca7fc6ea82c74fb71a2204a8c43f16e97e14d8f
%
% Notes:
% - This version removes operators (e.g., ~>, |) for predicates
%   to avoid shipping them in every project using Bakage.
%
% This library provides predicates to do pattern matching in a way that complements and
% expands on library(reif).
%
% Tested on Scryer Prolog 0.10.
%
% === Pattern matching ===
%
% The core predicate of this library is pattern_match_t/3. It has a non-reified version
% pattern_match/2, along with predicate aliases pattern_match_rev/2-3 (value first order).
%
% The pattern consists of a term that is a clean representation of what you want to match.
% You always need to specify how a term will be matched with a wrapping functor.

% --- ground: Ground term matching ---
%
% Matches a ground term. Doesn't need to be atomic.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3), ground(a(1,2,3))).
%      true.
%   ?- pattern_match_rev(a(1,2,3), ground(a(1,2,3)), T).
%      T = true.

% --- bind: Bind variable ---
%
% Binds a variable. This does normal unification, not reified unification like check.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3), bind(X)).
%      X = a(1,2,3).
%   ?- pattern_match_rev(a(1,2,3), bind(X), T).
%      X = a(1,2,3), T = true.

% --- check: Reified unification ---
%
% Does reified unification. If used in a non-reified predicate, it's basically the same
% thing as bind, but creates a spurious choice point. When used in a reified
% predicate, does the unification like =/3, exploring the dif/2 case on backtracking.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3), check(X)).
%      X = a(1,2,3)
%   ;  false.
%   ?- pattern_match_rev(a(1,2,3), check(X), T).
%      X = a(1,2,3), T = true
%   ;  T = false, dif:dif(X,a(1,2,3)).

% --- any: Wildcard ---
%
% Matches anything, and ignores it.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3), any).
%      true.
%   ?- pattern_match_rev(a(1,2,3), any, T).
%      T = true.

% --- composite: Compound term ---
%
% Matches a compound term, applying patterns recursively. If the compound term is ground,
% you can use ground instead.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3,4), composite(a(ground(1), bind(A), check(B), any))).
%      A = 2, B = 3
%   ;  false.
%   ?- pattern_match_rev(a(1,2,3,4), composite(a(ground(1), bind(A), check(B), any)), T).
%      A = 2, B = 3, T = true
%   ;  A = 2, T = false, dif:dif(B,3).

% --- bind_all: All binding ---
%
% Binds the whole pattern to a variable. It can be used at any nesting level, not just
% at the top level.
%
% Examples:
%   ?- pattern_match_rev(a(1,2,3,4), bind_all(All, composite(a(ground(1), bind(A), check(B), any)))).
%      All = a(1,2,3,4), A = 2, B = 3
%   ;  false.
%   ?- pattern_match_rev(a(1,2,3,4), bind_all(All, composite(a(ground(1), bind(A), check(B), any))), T).
%      All = a(1,2,3,4), A = 2, B = 3, T = true
%   ;  All = a(1,2,3,4), A = 2, T = false, dif:dif(B,3).

% --- guard: Guards ---
%
% Runs a reified predicate after the bindings to decide if the pattern matches.
%
% Examples:
%   ?- use_module(library(clpz)).
%      true.
%   ?- pattern_match_rev(a(50), guard(composite(a(bind(N))), clpz_t(N #< 25))).
%      false.
%   ?- pattern_match_rev(a(10), guard(composite(a(bind(N))), clpz_t(N #< 25))).
%      N = 10.
%   ?- pattern_match_rev(a(50), guard(composite(a(bind(N))), clpz_t(N #< 25)), T).
%      N = 50, T = false.
%   ?- pattern_match_rev(a(10), guard(composite(a(bind(N))), clpz_t(N #< 25)), T).
%      N = 10, T = true.

% === match/2: Reified pattern matching switch ===
%
% The match/2 predicate implements something like a switch/match statement on top of
% if_/3 and the pattern matching predicates from this library. The arms are matched in
% order, and the first one to succeed is the one taken.
%
% When a check pattern backtracks and tries the dif/2 case, it will test the next
% arms in the match/2. The dif/2 constraint will be available for all the arms
% from there on.
%
% Examples:
%   example_match(Term, Out) :-
%       match(Term, [
%           arm(ground(a), (Out = 1)),
%           arm(composite(b(bind(N))), (Out = N)),
%           arm(composite(c(check(N))), (Out = N)),
%           arm(any, (Out = wildcard))
%       ]).
%
%   ?- example_match(a, Out).
%      Out = 1.
%   ?- example_match(b(10), Out).
%      Out = 10.
%   ?- example_match(c(10), Out).
%      Out = 10
%   ;  Out = wildcard, dif:dif(_A,10).

% === Migration from operator version ===
%
% Old operator syntax -> New predicate syntax:
%   +Term              -> ground(Term)
%   -Var               -> bind(Var)
%   ?Var               -> check(Var)
%   *                  -> any
%   \Structure         -> composite(Structure)
%   All << Pattern     -> bind_all(All, Pattern)
%   Pattern | Guard    -> guard(Pattern, Guard)
%   Pattern ~> Goal    -> arm(Pattern, Goal)
%   Value =~ Pattern   -> pattern_match_rev(Value, Pattern)
%   Pattern ~= Value   -> pattern_match(Pattern, Value)

:- use_module(library(reif)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).

% === Helper predicates ===

and(true, true, true).
and(true, false, false).
and(false, true, false).
and(false, false, false).

%% pattern_match_rev(Value, Pattern) - emulates Value =~ Pattern
pattern_match_rev(Value, Pattern, T) :-
    pattern_match_t(Pattern, Value, T).
pattern_match_rev(Value, Pattern) :-
    pattern_match_t(Pattern, Value, true).

%% pattern_match(Pattern, Value) - emulates Pattern ~= Value
pattern_match(Pattern, Value, T) :-
    pattern_match_t(Pattern, Value, T).
pattern_match(Pattern, Value) :-
    pattern_match_t(Pattern, Value, true).

%% pattern_match_t(Pattern, Value, T).
%
% A predicate to check if a value matches a certain pattern.
% The pattern is a specially constructed term that describes
% a pattern so that this can be monotonic.
pattern_match_t(Pattern, Value, T) :-
    % TODO: Error handling of pattern arity.
    Pattern =.. [PatternKind|PatternArgs],
    inner_pattern_match(PatternKind, PatternArgs, Value, T).

% Pattern constructors - emulate the symbol operators
% any - emulates *
inner_pattern_match(any, [], _, true).

% bind - emulates -
inner_pattern_match(bind, [Variable], Value, true) :-
    Variable = Value.

% check - emulates ?
inner_pattern_match(check, [Variable], Value, T) :-
    =(Variable, Value, T).

% ground - emulates +
inner_pattern_match(ground, [Ground], Value, T) :-
    % TODO: Error handling
    ground(Ground),
    =(Ground, Value, T).

% composite - emulates \
inner_pattern_match(composite, [Composite], Value, T) :-
    Composite =.. [Functor|Args],
    length(Args, Arity),
    functor(Value, ValueFunctor, ValueArity),
    if_(
        Functor = ValueFunctor,
        if_(
            Arity = ValueArity,
            (
                Value =.. [_|ValueArgs],
                pattern_match_arguments(Args, ValueArgs, true, T)
            ),
            T = false
        ),
        T = false
    ).

% bind_all - emulates
inner_pattern_match(bind_all, [Variable, Pattern], Value, T) :-
    Variable = Value,
    pattern_match_t(Pattern, Value, T).

% guard - emulates | in patterns
inner_pattern_match(guard, [Pattern, Guard_1], Value, T) :-
    if_(
        pattern_match_t(Pattern, Value),
        call(Guard_1, T),
        T = false
    ).

pattern_match_arguments([], [], T, T).
pattern_match_arguments([Pattern|Patterns], [Arg|Args], T0, T) :-
    pattern_match_t(Pattern, Arg, T1),
    and(T0, T1, T2),
    pattern_match_arguments(Patterns, Args, T2, T).

% === match/2 predicate ===

%% match(Term, Arms)
% Pattern matching with multiple arms.
% Arms should be a list of arm(Pattern, Goal) terms
match(Term,Arms) :-
    match_run(Arms, Term).

match_run([], _) :- false.
match_run([arm(Pattern, Goal_0)|Arms], Term) :-
    if_(
        pattern_match_rev(Term, Pattern),
        call(Goal_0),
        match_run(Arms, Term)
    ).

:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(debug)).
:- use_module(library(files)).

is_list_t(Ls, T) :-
    match(Ls, [
        arm(ground([]), (T = true)),
        arm(composite([any | bind(Ls1)]), is_list_t(Ls1, T)),
        arm(any, (T = false))
    ]).


file_exists_t(P, true):- file_exists(P),!.
file_exists_t(_, false).

license_t_(license(name(N)), T):- is_list_t(N, T).

license_t_(license(name(N), path(P)), T) :-
    call((is_list_t(N), is_list_t(P)), T).

license_valid_path_t([], Result1, Result1).
license_valid_path_t([_,_|_], Result1, Result1).
license_valid_path_t([license(name(_))], Result1, Result1).
license_valid_path_t([license(name(_), path(P))], Result1, Result2):-
    if_(file_exists_t(P),
        (Result2 = Result1),
        (
          Err = "the path of the license is not valid",
          Result2 = error(Err),
          user_message_invalid_manifest(Err)
        )
    ).

license_t(X, T) :-
    match(X, [
        arm(composite(license(bind(N))), (license_t_(license(N), T))),
        arm(composite(license(bind(N), bind(P))), (license_t_(license(N, P), T))),
        arm(any, (T = false))
    ]).

name_t(X, T) :-
    match(X, [
        arm(composite(name(bind(N))), (is_list_t(N, T))),
        arm(any, (T = false))
    ]).

dependencies_t(X, T) :-
    match(X, [
        arm(composite(dependencies(bind(N))), (is_list_t(N, T))),
        arm(any, (T = false))
    ]).

main_file_t(X, T) :-
    match(X, [
        arm(composite(main_file(bind(N))), (is_list_t(N, T))),
        arm(any, (T = false))
    ]).

pattern_in_list([], _) --> [].

pattern_in_list([L|Ls], Pattern_t) -->
    {
        if_(call(Pattern_t, L),
            Match = [L],
            Match = []
        )
    },
    Match,
    pattern_in_list(Ls, Pattern_t).

% A valid manifest
valid_manifest_t(Manifest, Report, Valid) :-
    has_valid_name(Manifest, ValidName),
    has_valid_optional_main_file(Manifest, ValidMainFile),
    has_license(Manifest, ValidLicense),
    has_optional_dependencies(Manifest, ValidDendencies),
    if_((ValidName=success, ValidMainFile=success, ValidLicense=success, ValidDendencies=success),
        if_(memberd_t(dependencies(Deps), Manifest),
            (
                phrase(valid_dependencies(Deps), DepsReport),
                if_(all_dependencies_valid_t(DepsReport),
                    (
                        Report = [validate_manifest-success],
                        Valid=true
                    ),
                    (
                        Report = DepsReport,
                        Valid=false
                    )
                )
            ),
            (
                Report = [validate_manifest-success],
                Valid = true
            )

        ),
        (
            Report = [
                validate_manifest_name-ValidName,
                validate_manifest_main_file-ValidMainFile,
                validate_manifest_license-ValidLicense,
                validate_dependencies-ValidDendencies
                ],
            Valid = false
        )

    ).

% the message sent to the user when a dependency is malformed
user_message_malformed_dependency(D, Error):-
    current_output(Out),
    phrase_to_stream((portray_clause_(D), "is malformed: ", Error, "\n"), Out).

% the message sent to the user when there is a validation error
user_message_invalid_manifest(Error):-
    current_output(Out),
    phrase_to_stream(("The installation failed; cause:\n\t", Error, "\n"), Out).

% Is valid when there is 0 instance and the field is optional
has_a_field([], _, _, true, success).

% Is not valid when there is 0 instance and the field is not optional
has_a_field([], FieldName, PredicateForm, false, error(Es)):-
    phrase(format_("the '~s' of the package is not defined or does not have the a predicate of the form '~s'", [FieldName, PredicateForm]), Es),
    user_message_invalid_manifest(Es).

% Is valid when there is one instance of the field and the field value has the correct type
has_a_field([_], _, _, _, success).

% Is not valid when there are multiple instances of the field
has_a_field([_,_|_], FieldName, _, _, error(Es)):-
     phrase(format_("the package has multiple '~s'", [FieldName]), Es),
     user_message_invalid_manifest(Es).

has_valid_name(Manifest, Result):-
    phrase(pattern_in_list(Manifest, name_t), S),
    has_a_field(S, "name", "name(N)", false, Result).

has_valid_optional_main_file(Manifest, Result) :-
    phrase(pattern_in_list(Manifest, main_file_t), S),
    has_a_field(S, "main_file", "main_file(N)", true, Result).

has_license(Manifest, Result) :-
    phrase(pattern_in_list(Manifest, license_t), S),
    has_a_field(S, "license", "license(name(N));license(name(N), path(P))", false, Result1),
    license_valid_path_t(S, Result1, Result).

has_optional_dependencies(Manifest, Result):-
    phrase(pattern_in_list(Manifest, dependencies_t), S),
    has_a_field(S, "dependencies", "dependencies(D)", true, Result).

% A valid dependency
valid_dependencies([]) --> [].

valid_dependencies([dependency(Name, path(Path))| Ds]) --> {
    if_(
        (memberd_t(';', Name)
        ; memberd_t('|', Name)
        ; memberd_t(';', Path)
        ; memberd_t('|', Path)
        ),
        (
            Error = "the name and the path of the dependency should not contain an \";\" or an \"|\" caracter",
            M = validate_dependency(dependency(Name, path(Path)))-error(Error),
            user_message_malformed_dependency(dependency(Name, path(Path)), Error)
        ),
        M = validate_dependency(dependency(Name, path(Path)))-success
    )
    },
    [M],
    valid_dependencies(Ds).

valid_dependencies([dependency(Name, git(Url))| Ds]) --> {
    if_(
        (memberd_t(';', Name)
            ; memberd_t('|', Name)
            ; memberd_t(';', Url)
            ; memberd_t('|', Url)
        ),
        (
            Error = "the name of the dependency and the url should not contain an \";\" or an \"|\" caracter",
            M = validate_dependency(dependency(Name, git(Url)))-error(Error),
            user_message_malformed_dependency(dependency(Name, git(Url)), Error)
        ),
         M = validate_dependency(dependency(Name, git(Url)))-success
    )
    },
    [M],
    valid_dependencies(Ds).

valid_dependencies([dependency(Name, git(Url, branch(Branch)))| Ds]) --> {
    if_(
        (memberd_t(';', Name)
        ; memberd_t('|', Name)
        ; memberd_t(';', Url)
        ; memberd_t('|', Url)
        ; memberd_t(';', Branch)
        ; memberd_t('|', Branch)),
        (
            Error = "the name, the url and the branch of dependency should not contain an \";\" or an \"|\" caracter",
            M = validate_dependency(dependency(Name, git(Url, branch(Branch))))-error(Error),
            user_message_malformed_dependency(dependency(Name, git(Url, branch(Branch))), Error)
        ),(
            M = validate_dependency(dependency(Name, git(Url, branch(Branch))))-success
        )
    )
    },
    [M],
    valid_dependencies(Ds).

valid_dependencies([dependency(Name, git(Url, tag(Tag)))|Ds]) --> {
    if_(
        (memberd_t(';', Name)
        ; memberd_t('|', Name)
        ; memberd_t(';', Url)
        ; memberd_t('|', Url)
        ; memberd_t(';', Tag)
        ; memberd_t('|', Tag)),
        (
            Error = "the name, the url and the tag of dependency should not contain an \";\" or an \"|\" caracter",
            M = validate_dependency(dependency(Name, git(Url, tag(Tag))))-error(Error),
            user_message_malformed_dependency(dependency(Name, git(Url, tag(Tag))), Error)
        ),
        M = validate_dependency(dependency(Name, git(Url, tag(Tag))))-success
    )
    },
    [M],
    valid_dependencies(Ds).

valid_dependencies([dependency(Name, git(Url, hash(Hash)))|Ds]) --> {
    if_(
        (memberd_t(';', Name)
        ; memberd_t('|', Name)
        ; memberd_t(';', Url)
        ; memberd_t('|', Url)
        ; memberd_t(';', Hash)
        ; memberd_t('|', Hash)),
        (
            Error = "the name, the url and the hash of dependency should not contain an \";\" or an \"|\" caracter",
            M = validate_dependency(dependency(Name, git(Url, hash(Hash))))-error(Error),
            user_message_malformed_dependency(dependency(Name, git(Url, hash(Hash))), Error)
        ),
        M = validate_dependency(dependency(Name, git(Url, hash(Hash))))-success
    )
    },
    [M],
    valid_dependencies(Ds).

all_dependencies_valid_t([], true).
all_dependencies_valid_t([validate_dependency(_)-success| Vs], T) :-  all_dependencies_valid_t(Vs, T).
all_dependencies_valid_t([validate_dependency(_)-error(_)| _], false).

run :-
    (
        catch(
            main,
            Error,
            (
                portray_clause(Error),
                halt(1)
            )
        ),
        halt
    ;   phrase_to_stream("main predicate failed", user_output),
        halt(1)
    ).

main :-
    collect_relevant_env_vars(EnvVars),
    argv(Args),
    parse_args(Args, ParsedArgs),
    resolve_flags_and_task(ParsedArgs, EnvVars, GlobalFlags, Task),
    set_global_state(GlobalFlags),
    do_task(Task, GlobalFlags).

parse_args(Args, ParsedArgs) :-
    phrase(chunked_args(ChunkedArgs), Args),
    parse_chunked_args(ChunkedArgs, parsed_args([], []), ParsedArgs).

parse_chunked_args([], ParsedArgs, ParsedArgs).
parse_chunked_args([CA|CAs], ParsedArgs0, ParsedArgs) :-
    parse_chunked_arg(CA, ParsedArgs0, ParsedArgs1),
    parse_chunked_args(CAs, ParsedArgs1, ParsedArgs).

parse_chunked_arg(flag(Flag), parsed_args(Command, Flags0), parsed_args(Command, Flags)) :-
    options_upsert(Flag, Flags0, Flags).

parse_chunked_arg(command(Cmd), parsed_args(Command0, Flags), parsed_args(Command, Flags)) :-
    append(Command0, [Cmd], Command).

options_upsert(Option, Options0, Options) :-
    functor(Option, Functor, Arity),
    functor(Pattern, Functor, Arity),
    (   append([Before, [Pattern], After], Options0) ->
        append([Before, [Option], After], Options)
    ;   append(Options0, [Option], Options)
    ).

chunked_args([]) --> [].
chunked_args([CA|CAs]) --> chunked_arg(CA), chunked_args(CAs).

chunked_arg(flag(help)) --> ( ["-h"] ; ["--help"] ).
chunked_arg(flag(color(ColorPolicy))) -->
    ["--color"],
    [ColorPolicy0],
    { phrase(color_policy(ColorPolicy), ColorPolicy0) }.
chunked_arg(flag(color(ColorPolicy))) -->
    [ColorPolicy0],
    { phrase(("--color=", color_policy(ColorPolicy)), ColorPolicy0) }.
chunked_arg(command(install)) --> ["install"].

color_policy(auto) --> "auto".
color_policy(always) --> "always".
color_policy(never) --> "never".

collect_relevant_env_vars(EnvVars) :-
    (   getenv("NO_COLOR", NC) ->
        NoColor = NC
    ;   NoColor = unset
    ),
    (   getenv("CLICOLOR_FORCE", CCF) ->
        CliColorForce = CCF
    ;   CliColorForce = unset
    ),
    EnvVars = [
        no_color(NoColor),
        cli_color_force(CliColorForce)
    ].

resolve_flags_and_task(ParsedArgs, EnvVars, GlobalFlags, Task) :-
    ParsedArgs = parsed_args(Command, Flags),
    resolve_cli_color(EnvVars, Flags, CliColor),
    GlobalFlags = [
        cli_color(CliColor)
    ],
    resolve_task(Command, Flags, Task).

resolve_cli_color(EnvVars, Flags, CliColor) :-
    member(no_color(NoColor), EnvVars),
    member(cli_color_force(CliColorForce), EnvVars),
    (   member(color(ColorPolicy), Flags) ->
        true
    ;   ColorPolicy = auto
    ),
    CliColor0 = on,
    (   NoColor \= unset, NoColor \= "" ->
        CliColor1 = off
    ;   CliColor1 = CliColor0
    ),
    (   CliColorForce \= unset, CliColorForce \= "" ->
        CliColor2 = on
    ;   CliColor2 = CliColor1
    ),
    (   ColorPolicy == always ->
        CliColor = on
    ;   ColorPolicy == never ->
        CliColor = off
    ;   CliColor = CliColor2
    ).

resolve_task([], _, help(root)).
resolve_task([Command|Subcommands], Flags, Task) :-
    resolve_command_task(Command, Subcommands, Flags, Task).

resolve_command_task(install, [], Flags, Task) :-
    (   member(help, Flags) ->
        Task = help(install)
    ;   Task = install
    ).

set_global_state(GlobalFlags) :-
    (   member(cli_color(CliColor), GlobalFlags) ->
        assertz(cli_color(CliColor))
    ;   true
    ).

do_task(help(CommandPath), _) :-
    phrase_to_stream(help_text(CommandPath), user_output).

do_task(install, _) :-
    pkg_install(_).

% Uses global color configuration
ansi(Color) -->
    {
        cli_color(CliColor),
        phrase(ansi(CliColor, Color), Code)
    },
    Code.

ansi(off, _) --> "".
ansi(on, Color) --> ansi_(Color).

% Raw colors
ansi_(reset) --> "\x1b\[0m".
ansi_(bold) --> "\x1b\[1m".
ansi_(red) --> "\x1b\[31m".
ansi_(green) --> "\x1b\[32m".
ansi_(yellow) --> "\x1b\[33m".
ansi_(blue) --> "\x1b\[34m".
ansi_(magenta) --> "\x1b\[35m".
ansi_(cyan) --> "\x1b\[36m".
ansi_(white) --> "\x1b\[37m".

% Color aliases
ansi_(help_header) --> ansi_(yellow), ansi_(bold).
ansi_(help_option) --> ansi_(green), ansi_(bold).

% Uses global color configuration
color_text(Color, Text) -->
    {
        cli_color(CliColor),
        phrase(color_text(CliColor, Color, Text), ColorText)
    },
    ColorText.

% Accepts arbitrary grammar rule bodies
color_text(CliColor, Color, Text) -->
    { phrase(Text, Text1) },
    ansi(CliColor, Color),
    Text1,
    ansi(CliColor, reset).

help_text(CommandPath) -->
    {
        help_info(CommandPath, Description, Usage, Options, Commands)
    },
    help_description(Description),
    help_usage(Usage),
    help_option_table("Options", Options),
    help_option_table("Commands", Commands).

help_info(
    root,
    "Bakage: an experimental package manager for Prolog",
    "bakage [OPTIONS] [COMMAND]",
    [
        flag("color", none, "When to use color. Valid options: auto, always, never"),
        flag("help", "h", "Print help")
    ],
    [
        %command("init", "Create a new project in the current directory"),
        command("install", "Installs the dependencies of the current package")
        %command("new", "Create a new project in a new directory"),
        %command("run", "Runs the current package")
    ]
).
help_info(
    install,
    "Install package dependencies",
    "bakage install [OPTIONS]",
    [
        flag("color", none, "When to use color. Valid options: auto, always, never"),
        flag("help", "h", "Print help")
    ],
    []
).

options_width(Options, OptionWidth) :-
    options_width(Options, 0, OptionWidth0),
    OptionWidth is 2 + OptionWidth0 + 2.

options_width([], OptionWidth, OptionWidth).
options_width([Option|Options], OptionWidth0, OptionWidth) :-
    option_width(Option, Width),
    OptionWidth1 is max(OptionWidth0, Width),
    options_width(Options, OptionWidth1, OptionWidth).

option_width(flag(Long, _, _), Width) :-
    length(Long, Width0),
    Width is 4 + Width0.
option_width(command(Name, _), Width) :-
    length(Name, Width).

with_tail_newline([]) --> "\n".
with_tail_newline([H|T]) -->
    {
        Text = [H|T],
        phrase((..., [Last]), Text),
        if_(
            Last = '\n',
            WithNewline = Text,
            phrase((Text, "\n"), WithNewline)
        )
    },
    WithNewline.

help_description(Description) -->
    { phrase(Description, Description1) },
    with_tail_newline(Description1).

help_usage(Usage) -->
    "\n",
    color_text(help_header, "Usage:"),
    " ",
    color_text(help_option, Usage),
    "\n".

help_option_table(_, []) --> "".
help_option_table(Name, Options) -->
    { Options = [_|_] },
    "\n",
    color_text(help_header, (Name, ":")), "\n",
    { options_width(Options, OptionWidth) },
    help_option_table_(Options, OptionWidth).

help_option_table_([], _) --> "".
help_option_table_([Option|Options], OptionWidth) -->
    help_option_table_line(Option, OptionWidth),
    help_option_table_(Options, OptionWidth).

n_spaces(N) -->
    {
        length(Spaces, N),
        append(Spaces, _, [' '|Spaces])
    },
    Spaces.

help_option_table_line(command(Name, Description), OptionWidth) -->
    {
        length(Name, NameLen),
        PaddingLen is OptionWidth - NameLen - 2
    },
    n_spaces(2), color_text(help_option, Name), n_spaces(PaddingLen),
    with_tail_newline(Description).

help_option_table_line(flag(Long, Short, Description), OptionWidth) -->
    {
        length(Long, LongLen),
        PaddingLen is OptionWidth - LongLen - 6,
        if_(
            Short = none,
            phrase(n_spaces(4), ShortDesc),
            phrase(
                (color_text(help_option, ("-", Short)), ", "),
                ShortDesc
            )
        )
    },
    n_spaces(2),
    ShortDesc,
    color_text(help_option, ("--", Long)),
    n_spaces(PaddingLen),
    with_tail_newline(Description).

script_string("ensure_dependencies", "#!/bin/sh\nset -u\n\n# Fail instead of prompting for password in git commands.\nexport GIT_TERMINAL_PROMPT=0\n\nwrite_result() {\n    flock scryer_libs/temp/install_resp.pl.lock -c \\\n        \"printf \'result(\\\"%s\\\", %s).\\n\' \\\"$1\\\" \\\"$2\\\" >> scryer_libs/temp/install_resp.pl\"\n}\n\nwrite_success() {\n    write_result \"$1\" \"success\"\n}\n\nwrite_error() {\n    escaped_error=$(printf \'%s\' \"$2\" | sed -e \'s/\\\\/\\\\\\\\/g\' -e \'s/\"/\\\\\"/g\')\n    escaped_error=$(printf \'%s\' \"$escaped_error\" | tr \'\\r\\n\' \'\\\\n\')\n    escaped_error=$(printf \'%s\' \"$escaped_error\" | sed \'s/\xa0\/ /g\')\n    write_result \"$1\" \"error(\\\\\\\"$escaped_error\\\\\\\")\"\n}\n\ninstall_git_default() {\n    dependency_name=$1\n    git_url=$2\n\n    error_output=$(\n        git clone \\\n            --quiet \\\n            --depth 1 \\\n            --single-branch \\\n            \"${git_url}\" \\\n            \"scryer_libs/packages/${dependency_name}\" 2>&1 1>/dev/null\n    )\n\n    if [ -z \"$error_output\" ]; then\n        write_success \"${dependency_name}\"\n    else\n        write_error \"${dependency_name}\" \"$error_output\"\n    fi\n}\n\ninstall_git_branch() {\n    dependency_name=$1\n    git_url=$2\n    git_branch=$3\n\n    error_output=$(\n        git clone \\\n            --quiet \\\n            --depth 1 \\\n            --single-branch \\\n            --branch \"${git_branch}\" \\\n            \"${git_url}\" \\\n            \"scryer_libs/packages/${dependency_name}\" 2>&1 1>/dev/null\n    )\n\n    if [ -z \"$error_output\" ]; then\n        write_success \"${dependency_name}\"\n    else\n        write_error \"${dependency_name}\" \"$error_output\"\n    fi\n}\n\ninstall_git_tag() {\n    dependency_name=$1\n    git_url=$2\n    git_tag=$3\n\n    error_output=$(\n        git clone \\\n            --quiet \\\n            --depth 1 \\\n            --single-branch \\\n            --branch \"${git_tag}\" \\\n            \"${git_url}\" \\\n            \"scryer_libs/packages/${dependency_name}\" 2>&1 1>/dev/null\n    )\n\n    if [ -z \"$error_output\" ]; then\n        write_success \"${dependency_name}\"\n    else\n        write_error \"${dependency_name}\" \"$error_output\"\n    fi\n}\n\ninstall_git_hash() {\n    dependency_name=$1\n    git_url=$2\n    git_hash=$3\n\n    error_output=$(\n        git clone \\\n            --quiet \\\n            --depth 1 \\\n            --single-branch \\\n            \"${git_url}\" \\\n            \"scryer_libs/packages/${dependency_name}\" 2>&1 1>/dev/null\n    )\n\n    if [ -z \"$error_output\" ]; then\n        fetch_error=$(\n            git -C \"scryer_libs/packages/${dependency_name}\" fetch \\\n                --quiet \\\n                --depth 1 \\\n                origin \"${git_hash}\" 2>&1 1>/dev/null\n        )\n        switch_error=$(\n            git -C \"scryer_libs/packages/${dependency_name}\" switch \\\n                --quiet \\\n                --detach \\\n                \"${git_hash}\" 2>&1 1>/dev/null\n        )\n        combined_error=\"${fetch_error}; ${switch_error}\"\n\n        if [ -z \"$fetch_error\" ] && [ -z \"$switch_error\" ]; then\n            write_success \"${dependency_name}\"\n        else\n            write_error \"${dependency_name}\" \"$combined_error\"\n        fi\n    else\n        write_error \"${dependency_name}\" \"$error_output\"\n    fi\n}\n\ninstall_path() {\n    dependency_name=$1\n    dependency_path=$2\n\n    if [ -d \"${dependency_path}\" ]; then\n        error_output=$(ln -rsf \"${dependency_path}\" \"scryer_libs/packages/${dependency_name}\" 2>&1 1>/dev/null)\n\n        if [ -z \"$error_output\" ]; then\n            write_success \"${dependency_name}\"\n        else\n            write_error \"${dependency_name}\" \"$error_output\"\n        fi\n    else\n        write_error \"${dependency_name}\" \"${dependency_path} does not exist\"\n    fi\n}\n\nOLD_IFS=$IFS\nIFS=\'|\'\nset -- $DEPENDENCIES_STRING\nIFS=$OLD_IFS\n\ntouch scryer_libs/temp/install_resp.pl\n\nfor dependency in \"$@\"; do\n    unset dependency_term dependency_kind dependency_name git_url git_branch git_tag git_hash dependency_path\n\n    IFS=\';\'\n    set -- $dependency\n    IFS=$OLD_IFS\n\n    while [ \"$#\" -gt 0 ]; do\n        field=$1\n        shift\n\n        key=$(printf \"%s\" \"$field\" | cut -d= -f1)\n        value=$(printf \"%s\" \"$field\" | cut -d= -f2-)\n\n        case \"$key\" in\n        dependency_term) dependency_term=$value ;;\n        dependency_kind) dependency_kind=$value ;;\n        dependency_name) dependency_name=$value ;;\n        git_url) git_url=$value ;;\n        git_branch) git_branch=$value ;;\n        git_tag) git_tag=$value ;;\n        git_hash) git_hash=$value ;;\n        dependency_path) dependency_path=$value ;;\n        esac\n    done\n\n    printf \"Ensuring is installed: %s\\n\" \"${dependency_term}\"\n\n    case \"${dependency_kind}\" in\n    do_nothing) ;;\n\n    git_default)\n        install_git_default \"${dependency_name}\" \"${git_url}\" &\n        ;;\n    git_branch)\n        install_git_branch \"${dependency_name}\" \"${git_url}\" \"${git_branch}\" &\n        ;;\n    git_tag)\n        install_git_tag \"${dependency_name}\" \"${git_url}\" \"${git_tag}\" &\n        ;;\n    git_hash)\n        install_git_hash \"${dependency_name}\" \"${git_url}\" \"${git_hash}\" &\n        ;;\n    path)\n        install_path \"${dependency_name}\" \"${dependency_path}\" &\n        ;;\n    *)\n        printf \"Unknown dependency kind: %s\\n\" \"${dependency_kind}\"\n        write_error \"${dependency_name}\" \"Unknown dependency kind: ${dependency_kind}\"\n        ;;\n    esac\ndone\n\nwait\n\nrm -f scryer_libs/temp/install_resp.pl.lock\n").
