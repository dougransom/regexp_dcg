# Using Regular Expression Patterns in Prolog

This document provides usage examples and pattern matching examples with expected Prolog toplevel outputs for the regular expression library.

To load the backtracking regular expression engine, run:
```prolog
?- use_module(regexp_dcg).
   true.
```

## Usage Examples

### 1. Direct Pattern Match with phrase/2

Match a string directly against a regular expression pattern using phrase/2.

```prolog
?- phrase(re_match("a.*b", Match), "acb").
   Match = "acb"
;  false.
```

### 2. Pattern Compilation

Compile a regular expression pattern string into a reusable compiled structure.

```prolog
?- re_compile("a.*b", Compiled).
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_lit([a]),regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_dot),regexp_dcg:dcg_lit([b])])]),0)
;  false.
```

### 3. Match using Compiled Pattern

Execute a pre-compiled pattern inside phrase/2 for maximum performance.

```prolog
?- re_compile("a.*b", Compiled), phrase(re_match(Compiled, Match), "acb").
   Compiled = compiled(regexp_dcg:dcg_concat([regexp_dcg:dcg_lit([a]),regexp_dcg:dcg_concat([regexp_dcg:dcg_star(regexp_dcg:dcg_dot),regexp_dcg:dcg_lit([b])])]),0)
   Match = "acb"
;  false.
```

### 4. Inspect Compiled Pattern Cache

Inspect the dynamic compilation cache using re_cache_info/2 to check the number of cached patterns and their pattern keys.

```prolog
?- re_clear_cache, phrase(re_match("a.*b"), "acb"), phrase(re_match("[0-9]+"), "123"), re_cache_info(Count, Keys).
