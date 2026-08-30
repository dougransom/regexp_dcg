/**
  Provides common input validation, pattern parsing, match extraction, and state accessors
  shared across all regular expression engines (`regexp_dcg`, `regexp_tree`, `regexp_dfa`).
*/
:- module(regexp_common, [
    to_chars/2,
    pattern_ast/2,
    re_group/3,
    extract_match/3,
    take_n/3,
    state_full/2,
    state_groups/2,
    state_named/2,
    builtin_class_spec/2,
    match_builtin/2,
    match_builtin_t/3,
    char_range_t/4,
    char_lower/2,
    char_equal_ci/2,
    char_equal_ci_t/3,
    parse_flags/2,
    match_class/2,
    match_class_t/3,
    match_class_ci/2,
    match_class_ci_t/3,
    is_input_arg_t/2,
    pattern_cache/4,
    pattern_cache_t/5,
    pattern_cache_get/4,
    pattern_cache_put/4,
    clear_pattern_cache/1,
    pattern_cache_info/3,
    get_or_compile_pattern/5
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(library(clpz)).
:- use_module(library(reif)).
:- use_module(library(dif)).

:- use_module(regexp_ast, [re_ast_chars//1, is_ast/1]).

%% to_chars(+Input, -Chars)
%
% Unify `Chars` with a list of character codes from string `Input` (character list or atom).
% Raises `instantiation_error` if `Input` is unbound, or `domain_error(chars, Input)` if invalid type.
%
% Cuts (!) commit to the matched input type branch once validated, ensuring determinism
% and preventing fallthrough into the domain_error clause on backtracking.
to_chars(Input, _) :-
    var(Input),
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

%% pattern_ast(+Pattern, -AST)
%
% Convert a pattern string, atom, or pre-built AST term into a canonical AST term.
%
% Cut (!) commits to pre-built AST terms once validated by is_ast/1, preventing
% fallthrough into to_chars/2 (which would raise domain_error) on backtracking.
pattern_ast(AST, _) :-
    var(AST),
    instantiation_error(pattern_ast/2).
pattern_ast(AST, AST) :-
    is_ast(AST),
    !.
pattern_ast(Pattern, AST) :-
    to_chars(Pattern, Chars),
    phrase(re_ast_chars(AST), Chars).

:- dynamic(pattern_cache/4).

/**
  ### Unified Multi-Engine Pattern Caching System

  To eliminate redundant pattern parsing and automaton compilation overhead across
  regular expression engines (`regexp_tree`, `regexp_dcg`, `regexp_dfa`), `regexp_common`
  provides a centralized dynamic pattern cache database `pattern_cache/4`.

  #### Caching Policy:
  1. **Multi-Stage Caching**:
     - **AST Tier (`Kind = ast`)**: Stores parsed abstract syntax tree terms (`pattern_cache(ast, Key, AST, GroupCount)`). This tier allows any matching engine to reuse previously parsed ASTs regardless of which engine parsed the pattern string first.
     - **Engine Tier (`Kind = tree | dcg | dfa`)**: Stores pre-compiled engine structures (`pattern_cache(tree, Key, Automaton, GroupCount)`). On cache hits, matching bypasses both pattern parsing AND tree compilation, reaching $O(1)$ dispatch.

  2. **Lookup & Indexing**:
     - First-argument indexing on `Kind` ensures instant lookup without scanning unrelated engine entries.
     - Lookups use reified predicates (such as `pattern_cache_t/5`) compatible with `library(reif)` and `if_/3` conditionals.

  3. **Cache Invalidation & Clearing**:
     - `clear_pattern_cache(Kind)` clears entries for a specific engine (`tree`, `dcg`, `dfa`, `ast`).
     - `clear_pattern_cache(all)` clears all pattern cache entries globally across all engines.
*/

%% is_input_arg_t(+Arg, -Truth)
%
% Reified test for whether `Arg` is an instantiated input string (character list) or atom.
%
% Reification Explanation:
% Designed specifically for `library(reif)`'s `if_/3` conditional. Binds `Truth` to `true`
% if `Arg` is a valid input string (character list `list_si` or atom `atom_si`), or `false` otherwise.
is_input_arg_t(Arg, true) :-
    nonvar(Arg),
    ( list_si(Arg) ; atom_si(Arg) ), !.
is_input_arg_t(_Arg, false).

%% pattern_cache_t(+Kind, +Key, -Value, -Extra, -Truth)
%
% Reified truth-value helper for querying dynamic `pattern_cache/4` facts under `library(reif)`.
%
% Reification Explanation:
% `if_/3` requires a condition goal whose final argument unifies with `true` or `false`.
% Because standard dynamic database operations (`clause`, `\+`) are non-reified, `pattern_cache_t/5`
% encapsulates the double-clause pattern:
% - Clause 1: If `pattern_cache(Kind, Key, Value, Extra)` exists in the dynamic database, `Truth` unifies with `true` and binds `Value` and `Extra`.
% - Clause 2: If `\+ pattern_cache(Kind, Key, _, _)` holds, `Truth` unifies with `false`.
pattern_cache_t(Kind, Key, Value, Extra, true) :-
    pattern_cache(Kind, Key, Value, Extra).
pattern_cache_t(Kind, Key, _Value, _Extra, false) :-
    \+ pattern_cache(Kind, Key, _, _).

%% pattern_cache_get(+Kind, +Key, -Value, -Extra)
%
% Direct lookup for dynamic `pattern_cache(Kind, Key, Value, Extra)` fact.
pattern_cache_get(Kind, Key, Value, Extra) :-
    pattern_cache(Kind, Key, Value, Extra).

%% pattern_cache_put(+Kind, +Key, +Value, +Extra)
%
% Store entry `Value` with metadata `Extra` into `pattern_cache/4` database.
pattern_cache_put(Kind, Key, Value, Extra) :-
    assertz(pattern_cache(Kind, Key, Value, Extra)).

%% clear_pattern_cache(+Kind)
%
% Clear pattern cache entries for engine `Kind` or all engines (`Kind = all`).
clear_pattern_cache(all) :-
    !,
    retractall(pattern_cache(_, _, _, _)).
clear_pattern_cache(Kind) :-
    retractall(pattern_cache(Kind, _, _, _)).

%% pattern_cache_info(+Kind, -Count, -Keys)
%
% Retrieve count and list of cached keys for engine `Kind` or all engines (`Kind = all`).
pattern_cache_info(Kind, Count, Keys) :-
    if_(Kind = all,
        findall(Key, pattern_cache(_, Key, _, _), Keys),
        findall(Key, pattern_cache(Kind, Key, _, _), Keys)
    ),
    length(Keys, Count).

%% get_or_compile_pattern(+EngineKind, +Pattern, +CompileAstGoal, -CompiledValue, -Extra)
%
% Higher-order pattern cache manager shared across all regular expression engines.
%
% Resolves input `Pattern` to `CompiledValue` and metadata `Extra` using a 3-tier strategy:
% 1. **Engine Cache Hit**: If `pattern_cache(EngineKind, Pattern, CompiledValue, Extra)` exists, return it directly ($O(1)$).
% 2. **AST Cache Hit**: If `pattern_cache(ast, Pattern, AST, Extra)` exists, invoke `call(CompileAstGoal, AST, CompiledValue, Extra)` and cache the compiled result under `EngineKind`.
% 3. **Cache Miss**: Parse `Pattern` into `AST` via `pattern_ast/2`, compile via `call(CompileAstGoal, AST, CompiledValue, Extra)`, and cache both the `AST` and `CompiledValue`.
%
% Reification & Higher-Order Execution:
% - Uses `if_/3` reification via `pattern_cache_t/5` and `is_input_arg_t/2` to eliminate cuts (`!`).
% - Uses `call(CompileAstGoal, AST, CompiledValue, Extra)` to invoke the engine-specific compiler predicate dynamically.
get_or_compile_pattern(EngineKind, Pattern, CompileAstGoal, CompiledValue, Extra) :-
    if_(pattern_cache_t(EngineKind, Pattern, CompiledValue, Extra),
        true,
        get_or_compile_pattern_miss(EngineKind, Pattern, CompileAstGoal, CompiledValue, Extra)
    ).

get_or_compile_pattern_miss(EngineKind, Pattern, CompileAstGoal, CompiledValue, Extra) :-
    if_(pattern_cache_t(ast, Pattern, AST, Extra),
        call(CompileAstGoal, AST, CompiledValue, Extra),
        ( pattern_ast(Pattern, AST),
          call(CompileAstGoal, AST, CompiledValue, Extra),
          if_(is_input_arg_t(Pattern),
              pattern_cache_put(ast, Pattern, AST, Extra),
              true
          )
        )
    ),
    if_(is_input_arg_t(Pattern),
        pattern_cache_put(EngineKind, Pattern, CompiledValue, Extra),
        true
    ).

%% re_group(+NamedGroups, +Name, -Value)
%
% Lookup value of named group `Name` in `NamedGroups` key-value association list.
re_group(NamedGroups, Name, Value) :-
    member(Name-Value, NamedGroups).

%% extract_match(+Full, +Rest, -Match)
%
% Extract matched character sequence `Match` given original full input `Full` and remaining `Rest`.
extract_match(Full, Rest, Match) :-
    length(Full, LFull),
    length(Rest, LRest),
    LMatch #= LFull - LRest,
    take_n(LMatch, Full, Match).

%% take_n(+N, +List, -Prefix)
%
% Take first `N` elements from `List`.
take_n(0, _, []).
take_n(N, [H|T], [H|R]) :-
    N #> 0,
    N1 #= N - 1,
    take_n(N1, T, R).

%% state_full(+State, -Full)
state_full(state(Full, _, _, _), Full).

%% state_groups(+State, -Groups)
state_groups(state(_, Groups, _, _), Groups).

%% state_named(+State, -Named)
state_named(state(_, _, Named, _), Named).

/* Built-in and POSIX Character Class Specifications */

%% builtin_class_spec(+Class, -Specs)
% Declarative specification of built-in and POSIX character classes.
builtin_class_spec(digit, [range('0', '9')]).
builtin_class_spec('d',   [range('0', '9')]).

builtin_class_spec(word,  [range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')]).
builtin_class_spec('w',   [range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')]).

builtin_class_spec(space, [set(" \t\r\n\f\v")]).
builtin_class_spec('s',   [set(" \t\r\n\f\v")]).

builtin_class_spec(alnum, [range('a', 'z'), range('A', 'Z'), range('0', '9')]).
builtin_class_spec(alpha, [range('a', 'z'), range('A', 'Z')]).
builtin_class_spec(blank, [set(" \t")]).
builtin_class_spec(cntrl, [range('\x00\', '\x1F\'), char('\x7F\')]).
builtin_class_spec(graph, [range('!', '~')]).
builtin_class_spec(lower, [range('a', 'z')]).
builtin_class_spec(print, [range(' ', '~')]).
builtin_class_spec(punct, [set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")]).
builtin_class_spec(upper, [range('A', 'Z')]).
builtin_class_spec(xdigit,[range('0', '9'), range('a', 'f'), range('A', 'F')]).

%% match_builtin(+Class, +Char)
% Pure logical match for built-in or POSIX character class.
match_builtin(Class, C) :-
    match_builtin_t(Class, C, true).

%% match_builtin_t(+Class, +Char, -Truth)
% Reified pure match for built-in or POSIX character class using first-argument indexing and if_/3.
match_builtin_t(not_digit, C, Truth) :- match_builtin_t(digit, C, T0), reif_not(T0, Truth).
match_builtin_t('D', C, Truth)       :- match_builtin_t(digit, C, T0), reif_not(T0, Truth).
match_builtin_t(not_word, C, Truth)  :- match_builtin_t(word, C, T0), reif_not(T0, Truth).
match_builtin_t('W', C, Truth)       :- match_builtin_t(word, C, T0), reif_not(T0, Truth).
match_builtin_t(not_space, C, Truth) :- match_builtin_t(space, C, T0), reif_not(T0, Truth).
match_builtin_t('S', C, Truth)       :- match_builtin_t(space, C, T0), reif_not(T0, Truth).

match_builtin_t(digit, C, Truth)     :- match_specs_t([range('0', '9')], C, Truth).
match_builtin_t('d', C, Truth)       :- match_specs_t([range('0', '9')], C, Truth).
match_builtin_t(word, C, Truth)      :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')], C, Truth).
match_builtin_t('w', C, Truth)       :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9'), char('_')], C, Truth).
match_builtin_t(space, C, Truth)     :- match_specs_t([set(" \t\r\n\f\v")], C, Truth).
match_builtin_t('s', C, Truth)       :- match_specs_t([set(" \t\r\n\f\v")], C, Truth).

match_builtin_t(alnum, C, Truth)     :- match_specs_t([range('a', 'z'), range('A', 'Z'), range('0', '9')], C, Truth).
match_builtin_t(alpha, C, Truth)     :- match_specs_t([range('a', 'z'), range('A', 'Z')], C, Truth).
match_builtin_t(blank, C, Truth)     :- match_specs_t([set(" \t")], C, Truth).
match_builtin_t(cntrl, C, Truth)     :- match_specs_t([range('\x00\', '\x1F\'), char('\x7F\')], C, Truth).
match_builtin_t(graph, C, Truth)     :- match_specs_t([range('!', '~')], C, Truth).
match_builtin_t(lower, C, Truth)     :- match_specs_t([range('a', 'z')], C, Truth).
match_builtin_t(print, C, Truth)     :- match_specs_t([range(' ', '~')], C, Truth).
match_builtin_t(punct, C, Truth)     :- match_specs_t([set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")], C, Truth).
match_builtin_t(upper, C, Truth)     :- match_specs_t([range('A', 'Z')], C, Truth).
match_builtin_t(xdigit, C, Truth)    :- match_specs_t([range('0', '9'), range('a', 'f'), range('A', 'F')], C, Truth).

match_specs_t([], _C, false).
match_specs_t([Spec|Specs], C, Truth) :-
    match_spec_item_t(Spec, C, T0),
    if_(T0 = true,
        Truth = true,
        match_specs_t(Specs, C, Truth)).

match_spec_item_t(range(Min, Max), C, Truth) :-
    char_range_t(Min, Max, C, Truth).
match_spec_item_t(char(Ch), C, Truth) :-
    =(Ch, C, Truth).
match_spec_item_t(set(List), C, Truth) :-
    member_char_t(C, List, Truth).

member_char_t(_C, [], false).
member_char_t(C, [H|T], Truth) :-
    if_(C = H,
        Truth = true,
        member_char_t(C, T, Truth)).

char_range_t(Min, Max, Char, Truth) :-
    char_code(Min, MinCode),
    char_code(Max, MaxCode),
    char_code(Char, Code),
    MinCode #=< Code #<==> B1,
    Code #=< MaxCode #<==> B2,
    B1 #/\ B2 #<==> B,
    if_(B = 1, Truth = true, Truth = false).

reif_not(true, false).
reif_not(false, true).

/* Flag Parsing */

%% parse_flags(+FlagsInput, -ParsedFlags)
parse_flags(Flags, Parsed) :-
    to_chars(Flags, Chars),
    map_flags(Chars, Parsed).

map_flags([], []).
map_flags([C|Cs], [P|Ps]) :-
    map_flag_char(C, P),
    map_flags(Cs, Ps).

map_flag_char('i', case_insensitive).

/* Character Case Utilities */

%% char_lower(+Char, -LowerChar)
char_lower(C, L) :-
    if_(char_range_t('A', 'Z', C),
        ( char_code(C, Code),
          LowerCode #= Code + 32,
          char_code(L, LowerCode)
        ),
        L = C
    ).

%% char_equal_ci(+Char1, +Char2)
char_equal_ci(C1, C2) :-
    char_lower(C1, L),
    char_lower(C2, L).

%% char_equal_ci_t(+Char1, +Char2, -Truth)
char_equal_ci_t(C1, C2, Truth) :-
    char_lower(C1, L1),
    char_lower(C2, L2),
    =(L1, L2, Truth).

/* Pure Reified Character Class Matcher */

%% match_class(+Items, +Char)
match_class(Items, C) :-
    match_class_t(Items, C, true).

%% match_class_t(+Items, +Char, -Truth)
match_class_t(neg(List), C, Truth) :-
    match_class_items_t(List, C, T0),
    reif_not(T0, Truth).
match_class_t(List, C, Truth) :-
    list_si(List),
    match_class_items_t(List, C, Truth).

match_class_items_t([], _C, false).
match_class_items_t([Item|Items], C, Truth) :-
    match_class_item_t(Item, C, T0),
    if_(T0 = true,
        Truth = true,
        match_class_items_t(Items, C, Truth)).

match_class_item_t(char(Ch), C, Truth) :-
    =(Ch, C, Truth).
match_class_item_t(range(Min, Max), C, Truth) :-
    char_range_t(Min, Max, C, Truth).
match_class_item_t(builtin(Class), C, Truth) :-
    match_builtin_t(Class, C, Truth).

%% match_class_ci(+Items, +Char)
match_class_ci(Items, C) :-
    match_class_ci_t(Items, C, true).

%% match_class_ci_t(+Items, +Char, -Truth)
match_class_ci_t(neg(List), C, Truth) :-
    match_class_items_ci_t(List, C, T0),
    reif_not(T0, Truth).
match_class_ci_t(List, C, Truth) :-
    list_si(List),
    match_class_items_ci_t(List, C, Truth).

match_class_items_ci_t([], _C, false).
match_class_items_ci_t([Item|Items], C, Truth) :-
    match_class_item_ci_t(Item, C, T0),
    if_(T0 = true,
        Truth = true,
        match_class_items_ci_t(Items, C, Truth)).

match_class_item_ci_t(char(CharPattern), C, Truth) :-
    char_equal_ci_t(CharPattern, C, Truth).
match_class_item_ci_t(range(Min, Max), C, Truth) :-
    char_lower(Min, LowerA),
    char_lower(Max, LowerB),
    char_lower(C, LowerC),
    char_range_t(LowerA, LowerB, LowerC, Truth).
match_class_item_ci_t(builtin(Class), C, Truth) :-
    match_builtin_t(Class, C, Truth).
