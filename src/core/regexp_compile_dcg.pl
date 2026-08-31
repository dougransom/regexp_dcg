/**
  Provides a Definite Clause Grammar (DCG) regular expression engine for ISO Prolog systems.

  This module transforms regular expression strings into pure, executable DCG non-terminal
  expressions that match character sequences directly within Prolog grammars.

  ### Matching Paradigms

  1. **Direct & Embedded DCG Non-Terminal Matching (`re_match//1-2`, `re_match_groups//3`, `re_match_named//3`)**:
     Use matching non-terminals directly inside `phrase/2`, `phrase/3`, or embedded within custom DCG grammar rules:
     ```prolog
     ?- phrase(re_match("a*b", Match), "aaabc", Rest).
     % Match = "aaab", Rest = "c"
     ```
     Patterns passed directly to match predicates are automatically compiled into DCG goals and cached using the pattern string as the key. This avoids pattern parsing overhead when matching the same pattern repeatedly, but creates a compiled DCG entry in the cache database for each unique pattern that remains in memory. This could be an issue for programs using many different patterns (perhaps thousands). Use `re_clear_cache/0` to clear cached patterns or pre-compile patterns with `re_compile/2`.

  2. **Pre-Compiling Patterns (`re_compile/2`)**:
     Compile a regular expression pattern string into a reusable compiled DCG structure:
     ```prolog
     ?- re_compile("a*b", Compiled),
        phrase(re_match(Compiled, Match), "aaab").
     ```
     This avoids both pattern parsing overhead and cache lookup overhead on subsequent matches.

  ### Supported Regular Expression Syntax

  | Feature Category | Syntax | Description |
  |---|---|---|
  | **Literals** | `abc` | Match literal characters exactly. Escaped metacharacters (e.g. `\*`) match the metacharacter itself. |
  | **Wildcard** | `.` | Match any single character (except newline unless inline flag `s` is set). |
  | **Alternation** | `A\|B` | Match either sub-expression `A` or `B`. |
  | **Anchors** | `^` / `$` | Match the beginning or end of the input string. |
  | **Word Boundaries**| `\b` / `\B` | Match a word boundary or a non-word boundary. |
  | **Builtin Classes**| `\d` / `\D` | Match a digit `[0-9]` or not a digit `[^0-9]`. |
  | | `\w` / `\W` | Match a word character `[a-zA-Z0-9_]` or not a word character. |
  | | `\s` / `\S` | Match a whitespace character (space, tab, newline, carriage return, form feed, vertical tab) or not a whitespace. |
  | **Custom Classes** | `[abc]` / `[^abc]` | Match any character in the class (or not in the class if negated with `^`). |
  | | `[a-z]` / `[^a-z]` | Range matching inside character classes. |
  | | `[:digit:]` / `[:alpha:]` | POSIX character classes inside brackets (e.g. `[:alnum:]`, `[:space:]`). |
  | **Quantifiers** | `*` / `*?` | Greedy or lazy Kleene star (0 or more repetitions). |
  | | `+` / `+?` | Greedy or lazy Kleene plus (1 or more repetitions). |
  | | `?` / `??` | Greedy or lazy optional (0 or 1 repetition). |
  | | `{n}` / `{n}?` | Repetition exactly `n` times. |
  | | `{n,}` / `{n,}?` | Open-ended repetition: at least `n` times. |
  | | `{n,m}` / `{n,m}?`| Bounded repetition: between `n` and `m` times. |
  | **Groups & Captures**| `(...)` | Capturing group (extracts substring into numbered capture list). |
  | | `(?:...)` | Non-capturing group. |
  | | `(?P<name>...)` | Named capturing group. |
  | **Assertions** | `(?=...)` | Positive lookahead assertion. |
  | | `(?!...)` | Negative lookahead assertion. |
  | **Flags** | `(?flags)` | Inline flags setting: `i` (case-insensitive), `m` (multi-line), `s` (dot-all), `x` (verbose), etc. |
  | | `(?flags:...)` | Flags applied locally to a sub-expression group. |

  ### Multilingual & International Character Support

  In ISO Prolog systems treating `double_quotes` as character lists (`chars`), strings represent sequences of native character code points.
  Exact literal matching, wildcards (`.`), custom character classes (`[α-ω]`), capturing groups, Emojis, and non-Latin scripts (e.g. Greek, CJK, Klingon script PUA) work out of the box.

  > [!NOTE]
  > **Case-Insensitivity Limitation (`(?i)`)**: Inline flag `(?i)` case folding is currently scoped to ASCII characters (`'A'-'Z'` $\leftrightarrow$ `'a'-'z'`). Non-ASCII international uppercase/lowercase foldings (e.g. `'É'` $\leftrightarrow$ `'é'`) are not automatically folded by `(?i)`.
*/
:- module(regexp_compile_dcg, [
    /* =========================================================================
       Public User Interface
       All matching predicates are pure DCG non-terminals.
       Use with phrase/2 or phrase/3.
       ========================================================================= */
    re_match//1,             % DCG non-terminal prefix matcher (matches pattern)
    re_match//2,             % DCG non-terminal prefix matcher (unifies Match substring)
    re_match_groups//3,      % DCG non-terminal prefix matcher (unifies Match & Groups)
    re_match_named//3,       % DCG non-terminal prefix matcher (unifies Match & NamedGroups)
    re_match/2,              % Direct list matcher (anchored match)
    re_match/3,              % Direct list matcher (unanchored, returns Rest)
    re_match_groups/4,       % Direct list matcher (anchored, returns Match & Groups)
    re_match_groups/5,       % Direct list matcher (unanchored, returns Match, Groups & Rest)
    re_match_named/4,        % Direct list matcher (anchored, returns Match & NamedGroups)
    re_match_named/5,        % Direct list matcher (unanchored, returns Match, NamedGroups & Rest)
    re_group/3,              % Lookup captured group by name
    re_compile/2,            % Compile pattern to a reusable compiled structure
    re_clear_cache/0,        % Clear compiled pattern cache database
    re_cache_info/2,         % Inspect compiled pattern cache (Count, Keys)
    ast_dcg/4,
    ast_dcg_goal/4,
    pattern_compiled/3,
    pattern_ast/2,
    to_chars/2
]).

:- use_module(regexp_ast).
:- use_module(regexp_common).
:- use_module(library(si)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(error)).
:- use_module(library(clpz)).
:- use_module(library(reif)).
:- use_module(library(dif)).



/**
  ### Naming Conventions & State Threading

  This module follows standard Prolog difference-list and state-threading conventions:
  - `L0`, `L1`, ..., `L`: Input character sequence difference lists (threaded implicitly via DCG `-->` rules or explicitly via `phrase/3`). `L0` is the initial list before matching; `L` is the remaining list after matching.
  - `S0`, `S1`, ..., `SF`: Engine state structure `state(Full, Groups, Named, Tree)` threaded through match combinators (`S0` = initial state, `SF` = final state).
  - `C0`, `C1`, ..., `CF`: Integer counter threading (used at compile time for numbering capture group indices from initial count `C0` to final count `CF`).

  Reference:
  - DCGs & Difference Lists in Prolog: https://www.metalevel.at/prolog/dcg
*/

%% re_compile(+Pattern, -Compiled)
%
% Compile the regular expression `Pattern` (which can be a string, atom, or AST)
% into a reusable `Compiled` structure containing the matching goal and group count.
re_compile(Pattern, compiled(Goal, GroupCount)) :-
    pattern_ast(Pattern, AST),
    ast_dcg_goal(AST, 0, GroupCount, Goal).

pattern_compiled(Pattern, Goal, GroupCount) :-
    if_(is_compiled_t(Pattern),
        Pattern = compiled(Goal, GroupCount),
        pattern_compiled_cache(Pattern, Goal, GroupCount)
    ).

is_compiled_t(compiled(_, _), true).
is_compiled_t(Pattern, false) :-
    dif(Pattern, compiled(_, _)).

compile_ast_dcg(AST, Goal, GroupCount) :-
    ast_dcg_goal(AST, 0, GroupCount, Goal).

pattern_compiled_cache(Pattern, Goal, GroupCount) :-
    to_chars(Pattern, Key),
    get_or_compile_pattern(dcg, Key, regexp_compile_dcg:compile_ast_dcg, Goal, GroupCount).

%% re_clear_cache
%
% Clear all compiled patterns currently stored in the dynamic DCG engine cache.
re_clear_cache :-
    clear_pattern_cache(dcg).

%% re_cache_info(-Count, -Keys)
%
% Unifies `Count` with the total number of compiled patterns currently in the DCG cache,
% and `Keys` with the list of cached pattern key strings.
re_cache_info(Count, Keys) :-
    pattern_cache_info(dcg, Count, Keys).


%% re_match(+Pattern, ?Chars)
re_match(Pattern, Chars) :-
    re_match(Pattern, Chars, []).

%% re_match(+Pattern, ?Chars, -Rest)
% Direct 3-arg matcher and DCG //1 matcher
re_match(Pattern, Chars, Rest) :-
    phrase(re_match_groups_dcg(Pattern, _Match, _Groups), Chars, Rest).

%% re_match(+Pattern, -Match)//
% DCG //2 matcher (expanded to 4 args)
re_match(Pattern, Match, S0, S) :-
    phrase(re_match_groups_dcg(Pattern, Match, _Groups), S0, S).

%% re_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_match_groups(Pattern, Chars, Match, Groups) :-
    re_match_groups(Pattern, Chars, Match, Groups, []).

%% re_match_groups(+Pattern, ?InputOrMatch, ?MatchOrGroups, ?GroupsOrS0, ?RestOrS)
% Dual-purpose matcher:
% 1. Direct 5-arg list call: (Pattern, Input, Match, Groups, Rest)
% 2. DCG //3 expansion call: (Pattern, Match, Groups, S0, S)
re_match_groups(Pattern, InputOrMatch, MatchOrGroups, GroupsOrS0, RestOrS) :-
    if_(is_input_arg_t(InputOrMatch),
        ( to_chars(InputOrMatch, Input),
          phrase(re_match_groups_dcg(Pattern, MatchOrGroups, GroupsOrS0), Input, RestOrS) ),
        phrase(re_match_groups_dcg(Pattern, InputOrMatch, MatchOrGroups), GroupsOrS0, RestOrS)
    ).

re_match_groups_dcg(Pattern, Match, Groups, S0, S) :-
    re_match_dcg_state(Pattern, Match, _State0, SF, S0, S),
    state_groups(SF, Groups).

%% re_match_named(+Pattern, ?Chars, -Match, -NamedGroups)
re_match_named(Pattern, Chars, Match, NamedGroups) :-
    re_match_named(Pattern, Chars, Match, NamedGroups, []).

%% re_match_named(+Pattern, ?InputOrMatch, ?MatchOrNamed, ?NamedOrS0, ?RestOrS)
% Dual-purpose matcher:
% 1. Direct 5-arg list call: (Pattern, Input, Match, NamedGroups, Rest)
% 2. DCG //3 expansion call: (Pattern, Match, NamedGroups, S0, S)
re_match_named(Pattern, InputOrMatch, MatchOrNamed, NamedOrS0, RestOrS) :-
    if_(is_input_arg_t(InputOrMatch),
        ( to_chars(InputOrMatch, Input),
          phrase(re_match_named_dcg(Pattern, MatchOrNamed, NamedOrS0), Input, RestOrS) ),
        phrase(re_match_named_dcg(Pattern, InputOrMatch, MatchOrNamed), NamedOrS0, RestOrS)
    ).

re_match_named_dcg(Pattern, Match, NamedGroups, S0, S) :-
    re_match_dcg_state(Pattern, Match, _State0, SF, S0, S),
    state_named(SF, NamedGroups).

%% re_match_dcg_state(+Pattern, -Match, ?S0, -SF)//
%
% Helper for DCG matching. Initializes S0 if unbound, or extracts input from existing S0.
%   S0: Initial state | SF: Final state
%   L0: Initial input char list | L: Remaining unparsed input char list (L0 = Match + L)
re_match_dcg_state(Pattern, Match, S0, SF, L0, L) :-
    pattern_compiled(Pattern, Goal, GroupCount),
    if_(var_t(S0),
        ( length(Groups, GroupCount), S0 = state(L0, Groups, [], []) ),
        S0 = state(L0, _, _, _)
    ),
    % SF is the final state after Goal matches. L0 is input, L is remainder.
    call(Goal, S0, SF, L0, L),
    append(Match, L, L0).

var_t(X, true) :- var(X).
var_t(X, false) :- nonvar(X).


%% state_tree(+State, -Flags)
%
% Extract the execution flags list `Flags` from matcher `State`.
state_tree(state(_, _, _, Flags), Flags).

%% initial_state(?State)
%
% Unifies `State` with an initial empty state structure.
initial_state(state(_, [], [], _)).

%% state_match(+State, -Match)
%
% Alias for `state_full/2`, retrieving the matched character sequence.
state_match(State, Match) :-
    state_full(State, Match).

%% ast_dcg(+AST, +State0, -StateF, -DCG)
%
% Compiles the regex Abstract Syntax Tree `AST` into an executable DCG non-terminal `DCG`.
%
% Binds `DCG` to `call(Goal, State0, StateF)`. When `DCG` is passed to `phrase/2` or `phrase/3`,
% it executes the dynamic goal `Goal`, threading `State0 -> StateF` and input character
% difference lists `L0 -> L` at match time.
ast_dcg(AST, S0, SF, DCG) :-
    ast_dcg_goal(AST, 0, _, Goal),
    DCG = call(Goal, S0, SF).

%% ast_dcg_goal(+AST, +C0, -CF, -Goal)
%
% Compiles an AST term into an executable runtime DCG goal term `Goal`.
% Threads state accumulator `SIn -> SOut` at match-time and counts capture group indices `C0 -> CF` at compile-time.
ast_dcg_goal(lit(Chars), C, C, regexp_compile_dcg:dcg_lit(Chars)).
ast_dcg_goal(concat(A, B), C0, CF, regexp_compile_dcg:dcg_concat([GA, GB])) :-
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(concat(List), C0, CF, regexp_compile_dcg:dcg_concat(SubGoals)) :-
    seq_ast_dcg(List, C0, CF, SubGoals).
ast_dcg_goal(or(A, B), C0, CF, regexp_compile_dcg:dcg_or(GA, GB)) :-
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(group(Inner), C0, CF, Goal) :-
    ast_dcg_goal(Inner, C0, CF, Goal).
ast_dcg_goal(capture(Inner), C0, CF, regexp_compile_dcg:dcg_capture(C0, GInner)) :-
    C1 #= C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(postfix(Expr, star), C0, CF, regexp_compile_dcg:dcg_star(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, plus), C0, CF, regexp_compile_dcg:dcg_plus(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, question), C0, CF, regexp_compile_dcg:dcg_question(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, mn(M, N)), C0, CF, regexp_compile_dcg:dcg_quant(GExpr, M, N)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(dot, C, C, regexp_compile_dcg:dcg_dot).
ast_dcg_goal(escaped(Char), C, C, regexp_compile_dcg:dcg_lit([Char])).
ast_dcg_goal(anchor(bol), C, C, regexp_compile_dcg:dcg_bol).
ast_dcg_goal(anchor(eol), C, C, regexp_compile_dcg:dcg_eol).
ast_dcg_goal(builtin(Class), C, C, regexp_compile_dcg:dcg_builtin(Class)).
ast_dcg_goal(class(Items), C, C, regexp_compile_dcg:dcg_class(Items)).
ast_dcg_goal(lookahead(Sub), C0, CF, regexp_compile_dcg:dcg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(neg_lookahead(Sub), C0, CF, regexp_compile_dcg:dcg_neg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(postfix(Expr, lazy(star)), C0, CF, regexp_compile_dcg:dcg_star_lazy(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(plus)), C0, CF, regexp_compile_dcg:dcg_plus_lazy(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(question)), C0, CF, regexp_compile_dcg:dcg_question_lazy(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, lazy(mn(M, N))), C0, CF, regexp_compile_dcg:dcg_quant_lazy(GExpr, M, N)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(named_capture(Name, Inner), C0, CF, regexp_compile_dcg:dcg_named_capture(Name, C0, GInner)) :-
    C1 #= C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(flags(Flags), C, C, regexp_compile_dcg:dcg_flags(Flags)).
ast_dcg_goal(flags(Flags, Sub), C0, CF, regexp_compile_dcg:dcg_flags_group(Flags, GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).

seq_ast_dcg([], C, C, []).
seq_ast_dcg([H|T], C0, CF, [G|Gs]) :-
    ast_dcg_goal(H, C0, C1, G),
    seq_ast_dcg(T, C1, CF, Gs).

% DCG for literal matching
literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).



/* ---------- Runtime DCG combinators ---------- */

dcg_lit(Chars, S0, S0) -->
    { S0 = state(_, _, _, Flags) },
    { if_(memberd_t(case_insensitive, Flags), Case = ci, Case = exact) },
    dcg_lit_case(Case, Chars).

dcg_lit_case(ci, Chars) --> literal_match_case_insensitive(Chars).
dcg_lit_case(exact, Chars) --> literal_match(Chars).

dcg_concat([], S, S) --> [].
dcg_concat([G|Gs], S0, SF) -->
    call(G, S0, S1),
    dcg_concat(Gs, S1, SF).

dcg_or(GA, GB, S0, SF) -->
    call(GA, S0, SF)
  ; call(GB, S0, SF).

dcg_capture(Index, GInner, S0, SF) -->
    match_consumed(call(GInner, S0, SF), Match),
    {
        S0 = state(_, Groups, _, _),
        nth0(Index, Groups, Match)
    }.

match_consumed(Goal, Consumed, S0, S) :-
    phrase(Goal, S0, S),
    append(Consumed, S, S0).

dcg_star(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    dcg_star(GExpr, S1, SF)
  ; { S0 = SF }.

dcg_plus(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    (   dcg_star(GExpr, S1, SF)
    ;   { S1 = SF }
    ).

dcg_question(GExpr, S0, SF) -->
    call(GExpr, S0, SF)
  ; { S0 = SF }.

dcg_quant(GExpr, M, N, S0, SF) -->
    { if_(N = inf, Max = inf, Max = N) },
    dcg_quant_loop(GExpr, 0, M, Max, S0, SF).

dcg_quant_loop(GExpr, Count, Min, Max, S0, SF) -->
    { (Max == inf ; Count #< Max) },
    call(GExpr, S0, S1),
    { Count1 #= Count + 1 },
    dcg_quant_loop(GExpr, Count1, Min, Max, S1, SF).

dcg_quant_loop(_GExpr, Count, Min, _Max, S, S) -->
    { Count #>= Min }.

dcg_dot(S, S) -->
    [_].

dcg_bol(S, S, L0, L0) :-
    S = state(Full, _, _, _),
    L0 == Full.

dcg_eol(S, S, [], []).

dcg_builtin(Class, S, S) -->
    [C],
    { match_builtin(Class, C) }.


dcg_class(Items, S0, S0) -->
    [C],
    { S0 = state(_, _, _, Flags),
      if_(memberd_t(case_insensitive, Flags),
          match_class_ci(Items, C),
          match_class(Items, C)
      )
    }.


dcg_lookahead(GSub, S0, SF, L0, L0) :-
    phrase(call(GSub, S0, SF), L0, _).

dcg_neg_lookahead(GSub, S0, S0, L0, L0) :-
    \+ phrase(call(GSub, S0, _), L0, _).

/* ---------- Lazy combinators ---------- */

dcg_star_lazy(GExpr, S0, SF) -->
    { S0 = SF }
  ; call(GExpr, S0, S1),
    dcg_star_lazy(GExpr, S1, SF).

dcg_plus_lazy(GExpr, S0, SF) -->
    call(GExpr, S0, S1),
    dcg_star_lazy(GExpr, S1, SF).

dcg_question_lazy(GExpr, S0, SF) -->
    { S0 = SF }
  ; call(GExpr, S0, SF).

dcg_quant_lazy(GExpr, M, N, S0, SF) -->
    { if_(N = inf, Max = inf, Max = N) },
    dcg_quant_loop_lazy(GExpr, 0, M, Max, S0, SF).

dcg_quant_loop_lazy(_GExpr, Count, Min, _Max, S, S) -->
    { Count >= Min }.
dcg_quant_loop_lazy(GExpr, Count, Min, Max, S0, SF) -->
    { (Max == inf ; Count < Max) },
    call(GExpr, S0, S1),
    { Count1 is Count + 1 },
    dcg_quant_loop_lazy(GExpr, Count1, Min, Max, S1, SF).

/* ---------- Named capture combinator ---------- */

dcg_named_capture(Name, Index, GInner, S0, SF) -->
    match_consumed(call(GInner, S0, S1), Match),
    {
        S1 = state(Full, Groups, Named, Tree),
        nth0(Index, Groups, Match),
        SF = state(Full, Groups, [Name-Match|Named], Tree)
    }.

/* ---------- Case-insensitive support helpers ---------- */



literal_match_case_insensitive([]) --> [].
literal_match_case_insensitive([C|Cs]) -->
    [X],
    { char_equal_ci(C, X) },
    literal_match_case_insensitive(Cs).

/* ---------- Inline flags combinators ---------- */

dcg_flags(Flags, S0, SF, L, L) :-
    S0 = state(Full, Groups, Named, OldFlags),
    parse_flags(Flags, NewFlags),
    append(NewFlags, OldFlags, CombinedFlags),
    SF = state(Full, Groups, Named, CombinedFlags).

dcg_flags_group(Flags, GSub, S0, SF) -->
    {
        S0 = state(Full, Groups, Named, OldFlags),
        parse_flags(Flags, NewFlags),
        append(NewFlags, OldFlags, CombinedFlags),
        S1 = state(Full, Groups, Named, CombinedFlags)
    },
    call(GSub, S1, S2),
    {
        S2 = state(Full2, Groups2, Named2, _),
        SF = state(Full2, Groups2, Named2, OldFlags)
    }.

/*
   ========================================================================
   FAQ: Why are standard control operators (->, \+) used here instead of
        pure reified predicates (library(reif))?
   ========================================================================

   1. Standard Negation (\+) in Character Classes:
      Reifying a complex search check like match_class_list/2 (which handles
      ranges, standard term comparisons, and built-in digit/word classes)
      into a truth value (e.g., match_class_list_t/3) would be highly verbose
      and slow due to meta-call and boolean logical conjunction overheads.
      Since input characters are instantiated at matching time, standard
      negation-by-failure (\+) is safe, sound, and extremely performant.

   2. Control Flow (->) instead of if_/3:
      Standard -> is used for ground/instantiated check conditions, such as
      member(case_insensitive, Flags). When the condition is ground and
      deterministic, -> behaves purely and does not prune any alternative
      unification paths. In Scryer Prolog, it is compiled to a performant
      VM instruction, avoiding the overhead of invoking reified auxiliary
      predicates.
*/

 