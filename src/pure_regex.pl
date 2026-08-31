/**
  Provides the primary regular expression matching interface for ISO Prolog systems.

  By default, re-exports the Rational Tree Automaton engine (`src/core/regexp_tree.pl`).
  If `user:regexp_mode(dcg)` or `user:regexp_mode(dfa)` is asserted prior to loading,
  re-exports that engine implementation instead.

  ### Matching Paradigms

  1. **Direct List & Embedded DCG Matching (`re_match/2-3`, `re_match//1-2`)**:
     Use direct list matchers or embedded DCG non-terminals with `phrase/2` or `phrase/3`:
     ```prolog
     ?- re_match("a*b", "aaabc", Rest).
     % Rest = "c"

     ?- phrase(re_match("a*b", Match), "aaabc", Rest).
     % Match = "aaab", Rest = "c"
     ```

  2. **Pre-Compiling Patterns (`re_compile/2-3`)**:
     Compile a regular expression pattern string into a reusable compiled structure:
     ```prolog
     ?- re_compile("a*b", Compiled),
        re_match(Compiled, "aaabc", Rest).
     ```

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
:- module(pure_regex, [
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

:- use_module('core/regexp_tree').
