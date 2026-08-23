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
     Patterns passed directly to match predicates are automatically compiled into DCG goals and cached for subsequent calls.

  2. **Pre-Compiling Patterns (`re_compile/2`)**:
     Compile a regular expression pattern string into a reusable compiled DCG structure:
     ```prolog
     ?- re_compile("a*b", Compiled),
        phrase(re_match(Compiled, Match), "aaab").
     ```
     This avoids parsing overhead when matching the same pattern repeatedly across multiple inputs.

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
:- module(regexp_dcg, [
    /* =========================================================================
       Public User Interface
       All matching predicates are pure DCG non-terminals.
       Use with phrase/2 or phrase/3.
       ========================================================================= */
    re_match//1,             % DCG non-terminal prefix matcher (matches pattern)
    re_match//2,             % DCG non-terminal prefix matcher (unifies Match substring)
    re_match_groups//3,      % DCG non-terminal prefix matcher (unifies Match & Groups)
    re_match_named//3,       % DCG non-terminal prefix matcher (unifies Match & NamedGroups)
    re_group/3,              % Lookup captured group by name
    re_compile/2,            % Compile pattern to a reusable compiled structure
    re_clear_cache/0         % Clear compiled pattern cache database
]).

:- use_module(regexp_ast).
:- use_module(logs).
:- use_module(library(si)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(error)).

:- dynamic(pattern_cache/3).

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

pattern_compiled(compiled(Goal, GroupCount), Goal, GroupCount) :- !.
pattern_compiled(Pattern, Goal, GroupCount) :-
    to_chars(Pattern, Key),
    (   pattern_cache(Key, Goal0, GroupCount0) ->
        Goal = Goal0,
        GroupCount = GroupCount0
    ;   pattern_ast(Pattern, AST),
        ast_dcg_goal(AST, 0, GroupCount, Goal),
        assertz(pattern_cache(Key, Goal, GroupCount))
    ).

%% re_clear_cache
%
% Clear all compiled patterns currently stored in the dynamic `pattern_cache/3` database.
re_clear_cache :-
    retractall(pattern_cache(_, _, _)).

%% re_match(+Pattern)//
%
% DCG non-terminal prefix matcher. Matches a prefix of the input sequence
% that conforms to the regular expression `Pattern`.
re_match(Pattern) -->
    re_match_groups(Pattern, _Match, _Groups).

%% re_match(+Pattern, -Match)//
%
% DCG non-terminal prefix matcher. Matches a prefix of the input sequence
% that conforms to the regular expression `Pattern`, unifying `Match` with the matched characters.
re_match(Pattern, Match) -->
    re_match_groups(Pattern, Match, _Groups).

%% re_match_groups(+Pattern, -Match, -Groups)//
%
% DCG non-terminal prefix matcher. Matches a prefix of the input sequence conforming to `Pattern`,
% unifying `Match` with the matched characters and `Groups` with the list of captured group substrings,
% ordered in group-number order (left-to-right based on their opening parentheses).
% Definition: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html
re_match_groups(Pattern, Match, Groups) -->
    re_match_dcg_state(Pattern, Match, _S0, SF),
    {
        state_groups(SF, Groups)
    }.

%% re_match_named(+Pattern, -Match, -NamedGroups)//
%
% DCG non-terminal prefix matcher. Matches a prefix of the input sequence conforming to `Pattern`,
% unifying `Match` with the matched characters and `NamedGroups` with a list of Name-Value pairs
% representing the matched named capturing groups.
re_match_named(Pattern, Match, NamedGroups) -->
    re_match_dcg_state(Pattern, Match, _S0, SF),
    {
        state_named(SF, NamedGroups)
    }.

%% re_group(+NamedGroups, +Name, -Value)
%
% Retrieve the value of a named capturing group by its `Name`.
re_group(NamedGroups, Name, Value) :-
    member(Name-Value, NamedGroups).

%% re_match_dcg_state(+Pattern, -Match, ?S0, -SF)//
%
% Helper for DCG matching. Initializes S0 if unbound, or extracts input from existing S0.
%   S0: Initial state | SF: Final state
%   L0: Initial input char list | L: Remaining unparsed input char list (L0 = Match + L)
re_match_dcg_state(Pattern, Match, S0, SF, L0, L) :-
    pattern_compiled(Pattern, Goal, GroupCount),
    (   var(S0) ->
        % Initialize fresh state for top-level call
        length(Groups, GroupCount),
        S0 = state(L0, Groups, [], [])
    ;   % Use existing initial state
        S0 = state(L0, _, _, _)
    ),
    % SF is the final state after Goal matches. L0 is input, L is remainder.
    call(Goal, S0, SF, L0, L),
    append(Match, L, L0).

% Pattern already an AST
pattern_ast(AST, AST) :-
    nonvar(AST),
    is_ast(AST),
    !.

% Pattern is a string/atom: tokenize + parse
pattern_ast(Pattern, AST) :-
    to_chars(Pattern, Chars),
    phrase(re_ast_chars(AST), Chars).

%% state(?Full, ?Groups, ?Named, ?Flags)
%
% Matcher state term `state(Full, Groups, Named, Flags)` threaded through DCG goals:
%   1. Full:   Initial full input character list before matching (L0).
%   2. Groups: List of captured positional subgroup values [Group0, Group1, ...] ordered by group index.
%   3. Named:  List of captured named group Key-Value pairs [Name1-Val1, Name2-Val2, ...].
%   4. Flags:  Execution flags and options (e.g. `[case_insensitive]`).
state(_Full, _Groups, _Named, _Flags).

%% state_full(+State, -Full)
%
% Extract the initial full input character list `Full` from matcher `State`.
state_full(state(Full, _, _, _), Full).

%% state_groups(+State, -Groups)
%
% Extract the positional captured group substrings list `Groups` from matcher `State`.
state_groups(state(_, Groups, _, _), Groups).

%% state_named(+State, -Named)
%
% Extract the named captured group Key-Value pairs `Named` from matcher `State`.
state_named(state(_, _, Named, _), Named).

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

% ast_dcg_goal(+AST, +C0, -CF, -Goal)
% Compiles the AST into a runtime DCG goal that threads SIn -> SOut at match-time,
% while counting capture group indices C0 -> CF.
ast_dcg_goal(lit(Chars), C, C, regexp_dcg:dcg_lit(Chars)).
ast_dcg_goal(concat(A, B), C0, CF, regexp_dcg:dcg_concat([GA, GB])) :-
    !,
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(concat(List), C0, CF, regexp_dcg:dcg_concat(SubGoals)) :-
    seq_ast_dcg(List, C0, CF, SubGoals).
ast_dcg_goal(or(A, B), C0, CF, regexp_dcg:dcg_or(GA, GB)) :-
    ast_dcg_goal(A, C0, C1, GA),
    ast_dcg_goal(B, C1, CF, GB).
ast_dcg_goal(group(Inner), C0, CF, Goal) :-
    ast_dcg_goal(Inner, C0, CF, Goal).
ast_dcg_goal(capture(Inner), C0, CF, regexp_dcg:dcg_capture(C0, GInner)) :-
    C1 is C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(postfix(Expr, star), C0, CF, regexp_dcg:dcg_star(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, plus), C0, CF, regexp_dcg:dcg_plus(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, question), C0, CF, regexp_dcg:dcg_question(GExpr)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, mn(M, N)), C0, CF, regexp_dcg:dcg_quant(GExpr, M, N)) :-
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(dot, C, C, regexp_dcg:dcg_dot).
ast_dcg_goal(escaped(Char), C, C, regexp_dcg:dcg_lit([Char])).
ast_dcg_goal(anchor(bol), C, C, regexp_dcg:dcg_bol).
ast_dcg_goal(anchor(eol), C, C, regexp_dcg:dcg_eol).
ast_dcg_goal(builtin(Class), C, C, regexp_dcg:dcg_builtin(Class)).
ast_dcg_goal(class(Items), C, C, regexp_dcg:dcg_class(Items)).
ast_dcg_goal(lookahead(Sub), C0, CF, regexp_dcg:dcg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(neg_lookahead(Sub), C0, CF, regexp_dcg:dcg_neg_lookahead(GSub)) :-
    ast_dcg_goal(Sub, C0, CF, GSub).
ast_dcg_goal(postfix(Expr, lazy(star)), C0, CF, regexp_dcg:dcg_star_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(plus)), C0, CF, regexp_dcg:dcg_plus_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(postfix(Expr, lazy(question)), C0, CF, regexp_dcg:dcg_question_lazy(GExpr)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(quant(Expr, lazy(mn(M, N))), C0, CF, regexp_dcg:dcg_quant_lazy(GExpr, M, N)) :-
    !,
    ast_dcg_goal(Expr, C0, CF, GExpr).
ast_dcg_goal(named_capture(Name, Inner), C0, CF, regexp_dcg:dcg_named_capture(Name, C0, GInner)) :-
    !,
    C1 is C0 + 1,
    ast_dcg_goal(Inner, C1, CF, GInner).
ast_dcg_goal(flags(Flags), C, C, regexp_dcg:dcg_flags(Flags)).
ast_dcg_goal(flags(Flags, Sub), C0, CF, regexp_dcg:dcg_flags_group(Flags, GSub)) :-
    !,
    ast_dcg_goal(Sub, C0, CF, GSub).

seq_ast_dcg([], C, C, []).
seq_ast_dcg([H|T], C0, CF, [G|Gs]) :-
    ast_dcg_goal(H, C0, C1, G),
    seq_ast_dcg(T, C1, CF, Gs).

% DCG for literal matching
literal_match([]) --> [].
literal_match([C|Cs]) --> [C], literal_match(Cs).

% Convert input to character list safely without SWI-specifics (var check first!)
to_chars(Input, _) :-
    var(Input),
    !,
    instantiation_error(to_chars/2).
to_chars(Input, Input) :-
    list_si(Input),
    !.
to_chars(Input, Chars) :-
    atom_si(Input),
    !,
    atom_chars(Input, Chars).
to_chars(Input, _) :-
    domain_error(chars, Input).

/* ---------- Runtime DCG combinators ---------- */

dcg_lit(Chars, S0, SF) -->
    { S0 = state(_, _, _, Flags),
      member(case_insensitive, Flags) },
    !,
    literal_match_case_insensitive(Chars),
    { SF = S0 }.
dcg_lit(Chars, S0, S0) -->
    literal_match(Chars).

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
    { ( N == inf -> Max = inf ; integer(N) -> Max = N ) },
    dcg_quant_loop(GExpr, 0, M, Max, S0, SF).

dcg_quant_loop(GExpr, Count, Min, Max, S0, SF) -->
    { (Max == inf ; Count < Max) },
    call(GExpr, S0, S1),
    { Count1 is Count + 1 },
    dcg_quant_loop(GExpr, Count1, Min, Max, S1, SF).

dcg_quant_loop(_GExpr, Count, Min, _Max, S, S) -->
    { Count >= Min }.

dcg_dot(S, S) -->
    [_].

dcg_bol(S, S, L0, L0) :-
    S = state(Full, _, _, _),
    L0 == Full.

dcg_eol(S, S, [], []).

dcg_builtin(Class, S, S) -->
    [C],
    { match_builtin(Class, C) }.

match_builtin(digit, C) :-
    C @>= '0', C @=< '9'.
match_builtin(not_digit, C) :-
    \+ (C @>= '0', C @=< '9').
match_builtin(word, C) :-
    (C @>= 'a', C @=< 'z') ; (C @>= 'A', C @=< 'Z') ; (C @>= '0', C @=< '9') ; C == '_'.
match_builtin(not_word, C) :-
    \+ match_builtin(word, C).
match_builtin(space, C) :-
    member(C, [' ', '\t', '\r', '\n']).
match_builtin(not_space, C) :-
    \+ match_builtin(space, C).

dcg_class(Items, S0, SF) -->
    [C],
    { S0 = SF,
      S0 = state(_, _, _, Flags),
      (   member(case_insensitive, Flags) ->
          match_class_ci(Items, C)
      ;   match_class(Items, C)
      )
    }.

match_class(neg(List), C) :-
    !,
    \+ match_class_list(List, C).
match_class(List, C) :-
    list_si(List),
    match_class_list(List, C).

match_class_list([H|T], C) :-
    (   match_class_item(H, C) ->
        true
    ;   match_class_list(T, C)
    ).

match_class_item(char(C), C).
match_class_item(range(A, B), C) :-
    C @>= A, C @=< B.
match_class_item(builtin(Class), C) :-
    match_builtin(Class, C).

match_class_ci(neg(List), C) :-
    !,
    \+ match_class_list_ci(List, C).
match_class_ci(List, C) :-
    list_si(List),
    match_class_list_ci(List, C).

match_class_list_ci([H|T], C) :-
    (   match_class_item_ci(H, C) ->
        true
    ;   match_class_list_ci(T, C)
    ).

match_class_item_ci(char(CharPattern), C) :-
    char_equal_ci(CharPattern, C).
match_class_item_ci(range(A, B), C) :-
    char_lower(A, LowerA),
    char_lower(B, LowerB),
    char_lower(C, LowerC),
    LowerC @>= LowerA, LowerC @=< LowerB.
match_class_item_ci(builtin(Class), C) :-
    match_builtin(Class, C).

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
    { ( N == inf -> Max = inf ; integer(N) -> Max = N ) },
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

parse_flags(Flags, Parsed) :-
    to_chars(Flags, Chars),
    map_flags(Chars, Parsed).

map_flags([], []).
map_flags([C|Cs], [P|Ps]) :-
    map_flag_char(C, P),
    map_flags(Cs, Ps).

map_flag_char('i', case_insensitive).

char_lower(C, L) :-
    (   C @>= 'A', C @=< 'Z' ->
        char_code(C, Code),
        LowerCode is Code + 32,
        char_code(L, LowerCode)
    ;   L = C
    ).

char_equal_ci(C1, C2) :-
    char_lower(C1, L),
    char_lower(C2, L).

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

 