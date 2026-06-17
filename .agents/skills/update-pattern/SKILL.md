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
   To test matching when a pattern is not at the beginning of the input, combine the pattern with the helper `any_chars//0` rule.
   - For showing the rest of the input (using `phrase/3`):
     ```prolog
     phrase((any_chars, re_match_dcg("aa", Match)), "bbbbaaccccc", Rest)
     ```
   - For not showing the rest of the input (using `phrase/2`):
     ```prolog
     phrase((any_chars, re_match_dcg("aa", Match), any_chars), "bbbbaaccccc")
     ```
