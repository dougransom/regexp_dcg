---
name: update_pattern
description: Guidelines for adding new pattern tests to test_regexp_compile_dcg.pl using the phrase/DCG mechanism.
---

# Updating Pattern Tests

Whenever a new regular expression pattern feature is implemented, you must add corresponding unit tests to `tests/test_regexp_compile_dcg.pl`.

## Test Format Guidelines

1. **Use the DCG/phrase Interface**:
   By default, all pattern verification tests must use the `phrase/2` or `phrase/3` interface with `re_match_dcg//2` or `re_match_dcg//3` to demonstrate pattern usage.
   *Example*:
   ```prolog
   test("quantifier: greedy star",
       (phrase(re_match_dcg("a*", Match), "aaa"),
       Match == "aaa")).
   ```

2. **Group Capture Tests**:
   For tests verifying group capture, use `re_match_dcg//3` which returns both the full match and the captured groups.
   *Example*:
   ```prolog
   test("capture: single group",
       (phrase(re_match_dcg("(abc)", Match, Groups), "abc"),
       Match == "abc",
       Groups == ["abc"])).
   ```

3. **Unanchored / Middle-of-String Matching**:
   To test matching when a pattern is not at the beginning of the input, combine the pattern with the native `...` (three dots) DCG rule from `library(dcgs)`.
   - For showing the rest of the input (using `phrase/3`):
     ```prolog
     phrase((..., re_match_dcg("aa", Match)), "bbbbaaccccc", Rest)
     ```
   - For not showing the rest of the input (using `phrase/2`):
     ```prolog
     phrase((..., re_match_dcg("aa", Match), ...), "bbbbaaccccc")
     ```

4. **Update the Introduction Documentation**:
   When you add a new pattern test in `test_regexp_compile_dcg.pl`, you must also add a corresponding example query to `generate_intro_md.pl`.
   - Add a `run_query` statement before `close(Stream).` in `generate_intro_md.pl`.
   - Regenerate the documentation by running the script:
     ```bash
     nice scryer-safe -g main -g halt generate_intro_md.pl
     ```
   - Verify that the new query and its actual Scryer Prolog output (including bindings) are correctly added to [examples/regexp_intro.md](file:///home/doug/code/regexp/examples/regexp_intro.md).


