/**
  Provides a rational tree automaton regular expression matching interface for ISO Prolog systems.

  This module compiles regular expressions into rational tree (cyclic term) automata and matches
  them against character sequences using pure `if_/3` conditionals.

  ### Matching Paradigms

  1. **Direct List & Embedded DCG Matching (`re_tree_match/2-3`, `re_tree_match//1-2`)**:
     Use direct list matchers or embedded DCG non-terminals with `phrase/2` or `phrase/3`:
     ```prolog
     ?- re_tree_match("a*b", "aaabc", Rest).
     % Rest = "c"

     ?- phrase(re_tree_match("a*b", Match), "aaabc", Rest).
     % Match = "aaab", Rest = "c"
     ```
     Patterns passed directly to match predicates are automatically compiled into rational tree automata and cached using the pattern string as the key. This avoids pattern parsing overhead when matching the same pattern repeatedly, but creates a compiled automaton entry in the cache database for each unique pattern that remains in memory. Use `re_tree_clear_cache/0` to clear cached patterns or pre-compile patterns with `re_tree_compile/2`.

  2. **Pre-Compiling Patterns (`re_tree_compile/2`)**:
     Compile a regular expression pattern string into a reusable rational tree automaton:
     ```prolog
     ?- re_tree_compile("a*b", Tree),
        re_tree_match(Tree, "aaabc", Rest).
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
:- module(regexp_tree, [
    re_tree_match//1,
    re_tree_match//2,
    re_tree_match_groups//3,
    re_tree_match_named//3,
    re_tree_group/3,
    re_tree_compile/2,
    re_tree_clear_cache/0,
    re_tree_cache_info/2,
    re_tree_match/2,
    re_tree_match/3,
    re_tree_match_groups/4,
    re_tree_match_groups/5,
    re_tree_match_named/4,
    re_tree_match_named/5,
    % Standard Engine Aliases for shared test runner compatibility
    re_match//1,
    re_match//2,
    re_match_groups//3,
    re_match_named//3,
    re_match/2,
    re_match/3,
    re_match_groups/4,
    re_match_groups/5,
    re_match_named/4,
    re_match_named/5,
    re_group/3,
    re_compile/2,
    re_clear_cache/0,
    re_cache_info/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(library(reif)).

:- use_module(regexp_ast, [re_ast_chars//1, is_ast/1]).
:- use_module(regexp_common).
:- use_module(regexp_compile_tree, [compile_ast_tree/3, regex_tree_run/5]).

:- dynamic(tree_pattern_cache/3).

%% Standard Engine Aliases
re_match(Pattern, Chars) :- re_tree_match(Pattern, Chars).
re_match(Pattern, Chars, Rest) :- re_tree_match(Pattern, Chars, Rest).
re_match(Pattern, Match, S0, S) :- re_tree_match_groups_impl(Pattern, S0, Match, _Groups, S).
re_match_groups(Pattern, Chars, Match, Groups) :- re_tree_match_groups(Pattern, Chars, Match, Groups).
re_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :- re_tree_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5).
re_match_named(Pattern, Chars, Match, Named) :- re_tree_match_named(Pattern, Chars, Match, Named).
re_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :- re_tree_match_named(Pattern, Arg2, Arg3, Arg4, Arg5).
re_compile(Pattern, Compiled) :- re_tree_compile(Pattern, Compiled).
re_clear_cache :- re_tree_clear_cache.
re_cache_info(Count, Keys) :- re_tree_cache_info(Count, Keys).

%% re_tree_clear_cache
re_tree_clear_cache :-
    retractall(tree_pattern_cache(_, _, _)).

%% re_tree_cache_info(-Count, -Keys)
re_tree_cache_info(Count, Keys) :-
    findall(Key, tree_pattern_cache(Key, _, _), Keys),
    length(Keys, Count).

%% re_tree_group(+NamedGroups, +Name, -Value)
re_tree_group(NamedGroups, Name, Value) :-
    re_group(NamedGroups, Name, Value).

%% re_tree_compile(+Pattern, -CompiledTerm)
re_tree_compile(Pattern, compiled_tree(Automaton, GroupCount)) :-
    pattern_ast(Pattern, AST),
    compile_ast_tree(AST, Automaton, GroupCount).

%% re_tree_match(+Pattern, ?Chars)
re_tree_match(Pattern, Chars) :-
    re_tree_match(Pattern, Chars, []).

%% re_tree_match(+Pattern, ?Chars, -Rest)
re_tree_match(Pattern, Chars, Rest) :-
    re_tree_match_groups_impl(Pattern, Chars, _Match, _Groups, Rest).

%% re_tree_match(+Pattern, -Match)//
re_tree_match(Pattern, Match, S0, S) :-
    re_tree_match_groups_impl(Pattern, S0, Match, _Groups, S).

%% re_tree_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_tree_match_groups(Pattern, Chars, Match, Groups) :-
    re_tree_match_groups_impl(Pattern, Chars, Match, Groups, []).

%% re_tree_match_groups(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_tree_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    if_(is_input_arg_t(Arg2),
        re_tree_match_groups_impl(Pattern, Arg2, Arg3, Arg4, Arg5),
        re_tree_match_groups_impl(Pattern, Arg4, Arg2, Arg3, Arg5)
    ).

%% re_tree_match_named(+Pattern, ?Chars, -Match, -NamedGroups)
re_tree_match_named(Pattern, Chars, Match, NamedGroups) :-
    re_tree_match_named_impl(Pattern, Chars, Match, NamedGroups, []).

%% re_tree_match_named(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
re_tree_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    if_(is_input_arg_t(Arg2),
        re_tree_match_named_impl(Pattern, Arg2, Arg3, Arg4, Arg5),
        re_tree_match_named_impl(Pattern, Arg4, Arg2, Arg3, Arg5)
    ).

/* Internal Implementations */

re_tree_match_groups_impl(Pattern, Input, Match, Groups, Rest) :-
    to_chars(Input, Chars),
    get_tree_automaton(Pattern, Automaton, GroupCount),
    length(PosGroups, GroupCount),
    S0 = state(Chars, PosGroups, [], []),
    regex_tree_run(Chars, Automaton, S0, SF, Rest),
    state_groups(SF, Groups),
    extract_match(Chars, Rest, Match).

re_tree_match_named_impl(Pattern, Input, Match, NamedGroups, Rest) :-
    to_chars(Input, Chars),
    get_tree_automaton(Pattern, Automaton, GroupCount),
    length(PosGroups, GroupCount),
    S0 = state(Chars, PosGroups, [], []),
    regex_tree_run(Chars, Automaton, S0, SF, Rest),
    state_named(SF, NamedGroups),
    extract_match(Chars, Rest, Match).

/* Internal Helpers */

get_tree_automaton(Pattern, _, _) :-
    var(Pattern),
    !,
    instantiation_error(get_tree_automaton/3).
get_tree_automaton(compiled_tree(Automaton, GroupCount), Automaton, GroupCount) :- !.
get_tree_automaton(Pattern, Automaton, GroupCount) :-
    nonvar(Pattern),
    Pattern \= compiled_tree(_, _),
    if_(tree_pattern_cache_t(Pattern, AST, GroupCount),
        compile_ast_tree(AST, Automaton, GroupCount),
        ( pattern_ast(Pattern, AST),
          compile_ast_tree(AST, Automaton, GroupCount),
          if_(is_input_arg_t(Pattern),
              assertz(tree_pattern_cache(Pattern, AST, GroupCount)),
              true
          )
        )
    ).

tree_pattern_cache_t(Pattern, AST, GroupCount, true) :-
    tree_pattern_cache(Pattern, AST, GroupCount).
tree_pattern_cache_t(Pattern, _AST, _GroupCount, false) :-
    \+ tree_pattern_cache(Pattern, _, _).


