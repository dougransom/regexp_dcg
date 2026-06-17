# Using Regular Expression Patterns in Scryer Prolog

This document provides examples and expected Scryer Prolog toplevel outputs for all supported regular expression features in this library.

To load the backtracking regular expression engine, run:
```prolog
?- use_module(regexp_compile_dcg).
   true.
```

## Pattern Examples

### 1. DCG for Literal

Compile pattern into a DCG and match a string.

```prolog
?- pattern_ast("abc", AST), ast_dcg(AST, _S0, _S1, DCG), phrase(DCG, "abc").
   AST = lit([a,b,c])
   DCG = call(regexp_dcg:dcg_lit([a,b,c]),state(A,B,C,[case_insensitive|D]),state(A,B,C,[case_insensitive|D]))
;  false.
```

### 2. Simple Match

Basic matching of a literal pattern.

```prolog
?- phrase(re_match_dcg("abc", Match), "abc").
   Match = "abc"
;  false.
```

### 3. Alternation Precedence

Matching either sub-expression in alternation.

```prolog
?- phrase(re_match_dcg("a|bc", Match), "bc").
   Match = "bc"
;  false.
```

### 4. Grouping with Alternation

Explicit precedence using grouping parentheses.

```prolog
?- phrase(re_match_dcg("(a|b)c", Match), "ac").
   Match = "ac"
;  false.
```

### 5. Greedy Star Quantifier

Match zero or more times greedily.

```prolog
?- phrase(re_match_dcg("a*", Match), "aaa").
   Match = "aaa"
;  false.
```

### 6. Greedy Plus Quantifier

Match one or more times greedily.

```prolog
?- phrase(re_match_dcg("a+", Match), "aa").
   Match = "aa"
;  false.
```

### 7. Optional Quantifier (Match)

Match zero or one time greedily (optional matches).

```prolog
?- phrase(re_match_dcg("a?", Match), "a").
   Match = "a"
;  false.
```

### 8. Optional Quantifier (Empty)

Match zero or one time greedily (empty match).

```prolog
?- phrase(re_match_dcg("a?", Match), "").
   Match = ""
;  false.
```

### 9. Exact Repetition Quantifier

Match exactly N times.

```prolog
?- phrase(re_match_dcg("a{3}", Match), "aaa").
   Match = "aaa"
;  false.
```

### 10. Range Repetition Quantifier

Match between N and M times greedily.

```prolog
?- phrase(re_match_dcg("a{2,4}", Match), "aaaa").
   Match = "aaaa"
;  false.
```

### 11. Single Group Capture

Extract substrings captured by groups.

```prolog
?- phrase(re_match_dcg("(abc)", Match, Groups), "abc").
   Match = "abc"
   Groups = ["abc"]
;  false.
```

### 12. Nested Group Capture

Extract substrings captured by nested groups.

```prolog
?- phrase(re_match_dcg("(a(b)c)", Match, Groups), "abc").
   Match = "abc"
   Groups = ["abc", "b"]
;  false.
```

### 13. Star on Empty String

Edge case: greedy star matching empty string.

```prolog
?- phrase(re_match_dcg("a*", Match), "").
   Match = ""
;  false.
```

### 14. Nested Stars

Edge case: nested star operator.

```prolog
?- phrase(re_match_dcg("(a*)*", Match), "a").
   Match = "a"
;  false.
```

### 15. Character Classes (Simple)

Match any single character listed in brackets.

```prolog
?- phrase(re_match_dcg("[abc]", Match), "b").
   Match = "b"
;  false.
```

### 16. Character Classes (Negated)

Match any single character not listed in brackets.

```prolog
?- phrase(re_match_dcg("[^abc]", Match), "d").
   Match = "d"
;  false.
```

### 17. Wildcard Dot

Match any single character except newline.

```prolog
?- phrase(re_match_dcg("a.c", Match), "abc").
   Match = "abc"
;  false.
```

### 18. Builtin Digit Class

Match any digit character via `\d`.

```prolog
?- phrase(re_match_dcg("\\d", Match), "5").
   Match = "5"
;  false.
```

### 19. Builtin Word Class

Match any alphanumeric character plus underscore via `\w`.

```prolog
?- phrase(re_match_dcg("\\w", Match), "x").
   Match = "x"
;  false.
```

### 20. Start-of-Line Anchor

Match beginning of the input string via `^`.

```prolog
?- phrase(re_match_dcg("^a", Match), "a").
   Match = "a"
;  false.
```

### 21. End-of-Line Anchor

Match end of the input string via `$`.

```prolog
?- phrase(re_match_dcg("a$", Match), "a").
   Match = "a"
;  false.
```

### 22. Non-Greedy Quantifier

Match minimal number of repetitions via `*?`.

```prolog
?- phrase(re_match_dcg("a*?", Match), "a").
   Match = "a"
;  false.
```

### 23. Positive Lookahead Assertion

Match pattern only if followed by lookahead sub-expression.

```prolog
?- phrase(re_match_dcg("a(?=b)b", Match), "ab").
   Match = "ab"
;  false.
```

### 24. Named Group Capture

Syntax support for named capturing groups.

```prolog
?- phrase(re_match_dcg("(?P<id>abc)", Match), "abc").
   Match = "abc"
;  false.
```

### 25. Inline Case-Insensitive Flag

Enable case-insensitivity using inline flags.

```prolog
?- phrase(re_match_dcg("(?i)abc", Match), "ABC").
   Match = "ABC"
;  false.
```

### 26. Reified Matching (True)

Retrieve matching truth value in logically pure context (True case).

```prolog
?- re_match_t("abc", "abc", T).
   T = true
;  false.
```

### 27. Reified Matching (False)

Retrieve matching truth value in logically pure context (False case).

```prolog
?- re_match_t("abc", "def", T).
   T = false
;  false.
```

### 28. Reified Group Matching (True)

Reified matching with captured groups (True case).

```prolog
?- re_match_groups_t("(abc)", "abc", Match, Groups, T).
   Match = "abc"
   Groups = ["abc"]
   T = true
;  false.
```

### 29. Reified Group Matching (False)

Reified matching with captured groups (False case).

```prolog
?- re_match_groups_t("(abc)", "def", Match, Groups, T).
   Match = _
   Groups = _
   T = false
;  false.
```

### 30. Compile and Match

Manually compile a pattern and execute matching.

```prolog
?- re_compile("a*b", Compiled), re_match(Compiled, "aaab", Match).
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_lit([a])),regexp_dcg:dcg_lit([b])]),0)
   Match = "aaab"
;  false.
```

### 31. Compile and Reified Match

Manually compile a pattern and execute reified matching.

```prolog
?- re_compile("a*b", Compiled), re_match_t(Compiled, "aaab", T).
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_lit([a])),regexp_dcg:dcg_lit([b])]),0)
   T = true
;  false.
```

### 32. DCG Phrase Matcher Helper

Use DCG interface `re_match_dcg//2` inside phrase/2.

```prolog
?- phrase(re_match_dcg("a*b", Match), "aaabc", "c").
   Match = "aaab"
;  false.
```

### 33. DCG Phrase Matcher with Groups

Use DCG interface `re_match_dcg//3` with groups inside phrase/2.

```prolog
?- phrase(re_match_dcg("(a*)b", Match, Groups), "aaabc", "c").
   Match = "aaab"
   Groups = ["aaa"]
;  false.
```

### 34. DCG Phrase Matcher with Compiled Pattern

Use `re_match_dcg//2` with a pre-compiled pattern.

```prolog
?- re_compile("a*b", Compiled), phrase(re_match_dcg(Compiled, Match), "aaabc", "c").
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_lit([a])),regexp_dcg:dcg_lit([b])]),0)
   Match = "aaab"
;  false.
```

### 35. DCG Phrase Matcher with Compiled Pattern and Groups

Use `re_match_dcg//3` with a pre-compiled pattern and group extraction.

```prolog
?- re_compile("(a*)b", Compiled), phrase(re_match_dcg(Compiled, Match, Groups), "aaabc", "c").
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_capture(0,regexp_dcg:dcg_star(regexp_dcg:dcg_lit([a]))),regexp_dcg:dcg_lit([b])]),1)
   Match = "aaab"
   Groups = ["aaa"]
;  false.
```

### 36. Compilation Cache Matching

Access and verify the internal compilation cache.

```prolog
?- re_clear_cache, re_match("c*d", "cccd", Match), regexp_dcg:to_chars("c*d", Key), regexp_dcg:pattern_cache(Key, Goal, GroupCount).
   Match = "cccd"
   Key = "c*d"
   Goal = regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_lit([c])),regexp_dcg:dcg_lit([d])])
   GroupCount = 0
;  false.
```

### 37. Compilation Cache Clearing

Clear the cache database and verify no patterns remain.

```prolog
?- re_clear_cache, re_match("c*d", "cccd", Match), re_clear_cache, \+ regexp_dcg:pattern_cache(_, _, _).
;  false.
```

### 38. Unanchored Match (showing rest of input)

Match pattern inside input using phrase/3.

```prolog
?- phrase((any_chars, re_match_dcg("aa", Match)), "bbbbaaccccc", Rest).
   Match = "aa"
   Rest = "ccccc"
;  false.
```

### 39. Unanchored Match (no rest of input)

Match pattern inside input using phrase/2 (requires matching remaining suffix).

```prolog
?- phrase((any_chars, re_match_dcg("aa", Match), any_chars), "bbbbaaccccc").
   Match = "aa"
;  false.
```

