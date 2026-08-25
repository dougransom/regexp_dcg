:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(library(si)).
:- use_module('../regexp_tree').
:- use_module(test_regexp_compile_shared).

run_test(Name, Goal) :-
    (   catch(Goal, Error, (format("FAIL (~s): ~w~n", [Name, Error]), flush_output, fail)) ->
        format("OK: ~s~n", [Name]), flush_output
    ;   format("FAIL: ~s~n", [Name]), flush_output,
        false
    ).

test_tree_patterns :-
    % 1. Literal match
    run_test("Literal Match", re_tree_match("abc", "abc")),
    run_test("Literal Match Result", re_tree_match_groups("abc", "abc", "abc", [])),

    % 2. Alternation
    run_test("Alternation", re_tree_match("a|bc", "bc")),

    % 3. Grouping with Alternation
    run_test("Grouping with Alternation", re_tree_match("(a|b)c", "ac")),

    % 4. Star Quantifier
    run_test("Greedy Star", re_tree_match("a*", "aaa")),

    % 5. Plus Quantifier
    run_test("Greedy Plus", re_tree_match("a+", "aa")),

    % 6. Optional Quantifier
    run_test("Optional Match", re_tree_match("a?", "a")),
    run_test("Optional Empty", re_tree_match("a?", "")),

    % 7. Repetition
    run_test("Exact Repetition", re_tree_match("a{3}", "aaa")),
    run_test("Range Repetition", re_tree_match("a{2,4}", "aaaa")),

    % 8. Single Group Capture
    run_test("Single Group Capture", re_tree_match_groups("(abc)", "abc", "abc", ["abc"])),

    % 9. Nested Group Capture
    run_test("Nested Group Capture", re_tree_match_groups("(a(b)c)", "abc", "abc", ["abc", "b"])),

    % 10. Star on Empty String
    run_test("Star on Empty String", re_tree_match("a*", "")),

    % 11. Nested Stars
    run_test("Nested Stars", re_tree_match("(a*)*", "a")),

    % 12. Character Classes
    run_test("Character Class", re_tree_match("[abc]", "b")),
    run_test("Negated Character Class", re_tree_match("[^abc]", "d")),

    % 13. Wildcard Dot
    run_test("Wildcard Dot", re_tree_match("a.c", "abc")),

    % 14. Builtin Digit & Word
    run_test("Builtin Digit", re_tree_match("\\d", "5")),
    run_test("Builtin Word", re_tree_match("\\w", "x")),

    % 15. Anchors & Boundaries
    run_test("Start of Line Anchor", re_tree_match("^a", "a")),
    run_test("Word Boundary", re_tree_match("\\bcat\\b", "cat")),
    run_test("Non-Word Boundary", re_tree_match("s\\Bcat\\Bs", "scats")),

    % 16. Lazy (Non-Greedy) Quantifiers
    run_test("Non-Greedy Star", (re_tree_match("a*?b", "aaab", Rest16), Rest16 == [])),
    run_test("Non-Greedy Match Prefix", (re_tree_match("a*?", "aaa", Rest16b), Rest16b == "aaa")),

    % 17. Backreferences
    run_test("Backreference Match", re_tree_match("([a-z]+)-\\1", "abc-abc")),

    % 18. Inline Flags
    run_test("Inline Case-Insensitive Flag", re_tree_match("(?i)hello", "HeLLo")),

    % 19. Named Group Capture
    run_test("Named Group Capture", (re_tree_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", "john middle doe", Match19, Named19), nonvar(Match19), nonvar(Named19))),

    % 20. Pre-compilation
    run_test("Pre-compiled Tree", (
        re_tree_compile("a*b", Tree),
        re_tree_match(Tree, "aaabc", "c")
    )),

    % 21. DCG Wrapper
    run_test("DCG Wrapper", (phrase(re_tree_match("a*b", Match21), "aaabc", "c"), nonvar(Match21))),

    % 22. International
    run_test("International French", re_tree_match("café", "café")),
    run_test("International Greek", re_tree_match("α+β+", "αααβββ")),
    run_test("International Chinese", re_tree_match("你好", "你好")).

run_shared_tests :-
    shared_test(regexp_tree, Name, Goal),
    run_test(Name, Goal),
    fail.
run_shared_tests.

main :-
    test_tree_patterns,
    run_shared_tests,
    format("All regexp_tree tests completed.~n", []).

