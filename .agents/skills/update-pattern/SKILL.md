---
name: update_pattern
description: Guidelines for adding new pattern tests to test_regexp_compile_shared.pl using the phrase/DCG mechanism.
---

# Updating Pattern Tests

Whenever a new regular expression pattern feature is implemented, you must add corresponding unit tests to the shared test file `tests/test_regexp_compile_shared.pl`. Since tests are included in both `regexp_dcg` and `regexp_dfa` engines, tests must be defined as clauses of `shared_test(Engine, Name, Goal)`.

## Test Format Guidelines

1. **Use the Parameterized DCG/phrase Interface**:
   All shared pattern verification tests must use the `shared_test(Engine, Name, Goal)` predicate. Use the `phrase/2` or `phrase/3` interface with `Engine:re_match//2` or `Engine:re_match_groups//3` to demonstrate pattern usage.
   *Example*:
   ```prolog
   shared_test(Engine, "quantifier: greedy star",
       (phrase(Engine:re_match("a*", Match), "aaa"),
        Match == "aaa")).
   ```

2. **Group Capture Tests**:
   For tests verifying group capture, use `Engine:re_match_groups//3` which returns both the full match and the captured groups. Since the DFA engine does not support group extraction, conditionally run group validation or expect a domain error based on the value of `Engine`.
   *Example*:
   ```prolog
   shared_test(Engine, "capture: single group",
       (   Engine == regexp_dfa ->
           catch(phrase(Engine:re_match_groups("(abc)", _, _), "abc"), Error, true),
           nonvar(Error),
           Error = error(domain_error(dfa_group_extraction, _), _)
       ;   phrase(Engine:re_match_groups("(abc)", Match, Groups), "abc"),
           Match == "abc",
           Groups == ["abc"]
       )).
   ```

3. **Unanchored / Middle-of-String Matching**:
   To test matching when a pattern is not at the beginning of the input, combine the pattern with the native `...` (three dots) DCG rule from `library(dcgs)`.
   - For showing the rest of the input (using `phrase/3`):
     ```prolog
     phrase((..., Engine:re_match("aa", Match)), "bbbbaaccccc", Rest)
     ```
   - For not showing the rest of the input (using `phrase/2`):
     ```prolog
     phrase((..., Engine:re_match("aa", Match), ...), "bbbbaaccccc")
     ```

4. **Update the Introduction Documentation**:
   When you add a new pattern test in `tests/test_regexp_compile_shared.pl`, you must also add a corresponding example query to `generate_intro_md.pl`.
   - Add a `run_query` statement before `close(Stream).` in `generate_intro_md.pl`.
   - Regenerate the documentation by running the script:
     ```bash
     nice scryer-safe -g main -g halt generate_intro_md.pl
     ```
   - Verify that the new query and its actual Scryer Prolog output (including bindings) are correctly added to [examples/regexp_intro.md](file:///home/doug/code/regexp/examples/regexp_intro.md).
