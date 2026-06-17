:- use_module(regexp_compile_dcg).
:- use_module(library(format)).
:- use_module(library(si)).
:- use_module(library(lists)).
:- use_module(library(dcgs)).

% Custom value printer to match repl output format
print_val(Stream, Val) :-
    (   var(Val) ->
        format(Stream, "_", [])
    ;   chars_si(Val) ->
        format(Stream, "\"~s\"", [Val])
    ;   list_si(Val), maplist(chars_si, Val) ->
        format(Stream, "[", []),
        print_string_list(Stream, Val),
        format(Stream, "]", [])
    ;   format(Stream, "~w", [Val])
    ).

print_string_list(_, []).
print_string_list(Stream, [H|T]) :-
    format(Stream, "\"~s\"", [H]),
    (   T = [] ->
        true
    ;   format(Stream, ", ", []),
        print_string_list(Stream, T)
    ).

print_bindings(_, [], []).
print_bindings(Stream, [Name|Names], [Val|Vals]) :-
    format(Stream, "   ~s = ", [Name]),
    print_val(Stream, Val),
    nl(Stream),
    print_bindings(Stream, Names, Vals).

run_query(Stream, Title, Desc, QueryStr, Goal, VarNames, VarValues) :-
    format(Stream, "### ~s~n~n", [Title]),
    format(Stream, "~s~n~n", [Desc]),
    format(Stream, "```prolog~n", []),
    format(Stream, "?- ~s.~n", [QueryStr]),
    (   Goal ->
        print_bindings(Stream, VarNames, VarValues),
        format(Stream, ";  false.~n", [])
    ;   format(Stream, "   false.~n", [])
    ),
    format(Stream, "```~n~n", []).

main :-
    open('examples/regexp_intro.md', write, Stream),
    format(Stream, "# Using Regular Expression Patterns in Scryer Prolog~n~n", []),
    format(Stream, "This document provides examples and expected Scryer Prolog toplevel outputs for all supported regular expression features in this library.~n~n", []),
    format(Stream, "To load the backtracking regular expression engine, run:~n", []),
    format(Stream, "```prolog~n?- use_module(regexp_compile_dcg).~n   true.~n```~n~n", []),
    format(Stream, "## Pattern Examples~n~n", []),

    % Run all 39 queries
    run_query(Stream, "1. DCG for Literal", "Compile pattern into a DCG and match a string.",
              "pattern_ast(\"abc\", AST), ast_dcg(AST, _S0, _S1, DCG), phrase(DCG, \"abc\")",
              (pattern_ast("abc", AST), ast_dcg(AST, _S0, _S1, DCG), phrase(DCG, "abc")),
              ["AST", "DCG"], [AST, DCG]),

    run_query(Stream, "2. Simple Match", "Basic matching of a literal pattern.",
              "phrase(re_match_dcg(\"abc\", Match), \"abc\")",
              phrase(re_match_dcg("abc", Match2), "abc"),
              ["Match"], [Match2]),

    run_query(Stream, "3. Alternation Precedence", "Matching either sub-expression in alternation.",
              "phrase(re_match_dcg(\"a|bc\", Match), \"bc\")",
              phrase(re_match_dcg("a|bc", Match3), "bc"),
              ["Match"], [Match3]),

    run_query(Stream, "4. Grouping with Alternation", "Explicit precedence using grouping parentheses.",
              "phrase(re_match_dcg(\"(a|b)c\", Match), \"ac\")",
              phrase(re_match_dcg("(a|b)c", Match4), "ac"),
              ["Match"], [Match4]),

    run_query(Stream, "5. Greedy Star Quantifier", "Match zero or more times greedily.",
              "phrase(re_match_dcg(\"a*\", Match), \"aaa\")",
              phrase(re_match_dcg("a*", Match5), "aaa"),
              ["Match"], [Match5]),

    run_query(Stream, "6. Greedy Plus Quantifier", "Match one or more times greedily.",
              "phrase(re_match_dcg(\"a+\", Match), \"aa\")",
              phrase(re_match_dcg("a+", Match6), "aa"),
              ["Match"], [Match6]),

    run_query(Stream, "7. Optional Quantifier (Match)", "Match zero or one time greedily (optional matches).",
              "phrase(re_match_dcg(\"a?\", Match), \"a\")",
              phrase(re_match_dcg("a?", Match7), "a"),
              ["Match"], [Match7]),

    run_query(Stream, "8. Optional Quantifier (Empty)", "Match zero or one time greedily (empty match).",
              "phrase(re_match_dcg(\"a?\", Match), \"\")",
              phrase(re_match_dcg("a?", Match8), ""),
              ["Match"], [Match8]),

    run_query(Stream, "9. Exact Repetition Quantifier", "Match exactly N times.",
              "phrase(re_match_dcg(\"a{3}\", Match), \"aaa\")",
              phrase(re_match_dcg("a{3}", Match9), "aaa"),
              ["Match"], [Match9]),

    run_query(Stream, "10. Range Repetition Quantifier", "Match between N and M times greedily.",
              "phrase(re_match_dcg(\"a{2,4}\", Match), \"aaaa\")",
              phrase(re_match_dcg("a{2,4}", Match10), "aaaa"),
              ["Match"], [Match10]),

    run_query(Stream, "11. Single Group Capture", "Extract substrings captured by groups.",
              "phrase(re_match_dcg(\"(abc)\", Match, Groups), \"abc\")",
              phrase(re_match_dcg("(abc)", Match11, Groups11), "abc"),
              ["Match", "Groups"], [Match11, Groups11]),

    run_query(Stream, "12. Nested Group Capture", "Extract substrings captured by nested groups.",
              "phrase(re_match_dcg(\"(a(b)c)\", Match, Groups), \"abc\")",
              phrase(re_match_dcg("(a(b)c)", Match12, Groups12), "abc"),
              ["Match", "Groups"], [Match12, Groups12]),

    run_query(Stream, "13. Star on Empty String", "Edge case: greedy star matching empty string.",
              "phrase(re_match_dcg(\"a*\", Match), \"\")",
              phrase(re_match_dcg("a*", Match13), ""),
              ["Match"], [Match13]),

    run_query(Stream, "14. Nested Stars", "Edge case: nested star operator.",
              "phrase(re_match_dcg(\"(a*)*\", Match), \"a\")",
              phrase(re_match_dcg("(a*)*", Match14), "a"),
              ["Match"], [Match14]),

    run_query(Stream, "15. Character Classes (Simple)", "Match any single character listed in brackets.",
              "phrase(re_match_dcg(\"[abc]\", Match), \"b\")",
              phrase(re_match_dcg("[abc]", Match15), "b"),
              ["Match"], [Match15]),

    run_query(Stream, "16. Character Classes (Negated)", "Match any single character not listed in brackets.",
              "phrase(re_match_dcg(\"[^abc]\", Match), \"d\")",
              phrase(re_match_dcg("[^abc]", Match16), "d"),
              ["Match"], [Match16]),

    run_query(Stream, "17. Wildcard Dot", "Match any single character except newline.",
              "phrase(re_match_dcg(\"a.c\", Match), \"abc\")",
              phrase(re_match_dcg("a.c", Match17), "abc"),
              ["Match"], [Match17]),

    run_query(Stream, "18. Builtin Digit Class", "Match any digit character via `\\d`.",
              "phrase(re_match_dcg(\"\\\\d\", Match), \"5\")",
              phrase(re_match_dcg("\\d", Match18), "5"),
              ["Match"], [Match18]),

    run_query(Stream, "19. Builtin Word Class", "Match any alphanumeric character plus underscore via `\\w`.",
              "phrase(re_match_dcg(\"\\\\w\", Match), \"x\")",
              phrase(re_match_dcg("\\w", Match19), "x"),
              ["Match"], [Match19]),

    run_query(Stream, "20. Start-of-Line Anchor", "Match beginning of the input string via `^`.",
              "phrase(re_match_dcg(\"^a\", Match), \"a\")",
              phrase(re_match_dcg("^a", Match20), "a"),
              ["Match"], [Match20]),

    run_query(Stream, "21. End-of-Line Anchor", "Match end of the input string via `$`.",
              "phrase(re_match_dcg(\"a$\", Match), \"a\")",
              phrase(re_match_dcg("a$", Match21), "a"),
              ["Match"], [Match21]),

    run_query(Stream, "22. Non-Greedy Quantifier", "Match minimal number of repetitions via `*?`.",
              "phrase(re_match_dcg(\"a*?\", Match), \"a\")",
              phrase(re_match_dcg("a*?", Match22), "a"),
              ["Match"], [Match22]),

    run_query(Stream, "23. Positive Lookahead Assertion", "Match pattern only if followed by lookahead sub-expression.",
              "phrase(re_match_dcg(\"a(?=b)b\", Match), \"ab\")",
              phrase(re_match_dcg("a(?=b)b", Match23), "ab"),
              ["Match"], [Match23]),

    run_query(Stream, "24. Named Group Capture", "Syntax support for named capturing groups.",
              "phrase(re_match_dcg(\"(?P<id>abc)\", Match), \"abc\")",
              phrase(re_match_dcg("(?P<id>abc)", Match24), "abc"),
              ["Match"], [Match24]),

    run_query(Stream, "25. Inline Case-Insensitive Flag", "Enable case-insensitivity using inline flags.",
              "phrase(re_match_dcg(\"(?i)abc\", Match), \"ABC\")",
              phrase(re_match_dcg("(?i)abc", Match25), "ABC"),
              ["Match"], [Match25]),

    run_query(Stream, "26. Reified Matching (True)", "Retrieve matching truth value in logically pure context (True case).",
              "re_match_t(\"abc\", \"abc\", T)",
              re_match_t("abc", "abc", T26),
              ["T"], [T26]),

    run_query(Stream, "27. Reified Matching (False)", "Retrieve matching truth value in logically pure context (False case).",
              "re_match_t(\"abc\", \"def\", T)",
              re_match_t("abc", "def", T27),
              ["T"], [T27]),

    run_query(Stream, "28. Reified Group Matching (True)", "Reified matching with captured groups (True case).",
              "re_match_groups_t(\"(abc)\", \"abc\", Match, Groups, T)",
              re_match_groups_t("(abc)", "abc", Match28, Groups28, T28),
              ["Match", "Groups", "T"], [Match28, Groups28, T28]),

    run_query(Stream, "29. Reified Group Matching (False)", "Reified matching with captured groups (False case).",
              "re_match_groups_t(\"(abc)\", \"def\", Match, Groups, T)",
              re_match_groups_t("(abc)", "def", Match29, Groups29, T29),
              ["Match", "Groups", "T"], [Match29, Groups29, T29]),

    run_query(Stream, "30. Compile and Match", "Manually compile a pattern and execute matching.",
              "re_compile(\"a*b\", Compiled), re_match(Compiled, \"aaab\", Match)",
              (re_compile("a*b", Compiled30), re_match(Compiled30, "aaab", Match30)),
              ["Compiled", "Match"], [Compiled30, Match30]),

    run_query(Stream, "31. Compile and Reified Match", "Manually compile a pattern and execute reified matching.",
              "re_compile(\"a*b\", Compiled), re_match_t(Compiled, \"aaab\", T)",
              (re_compile("a*b", Compiled31), re_match_t(Compiled31, "aaab", T31)),
              ["Compiled", "T"], [Compiled31, T31]),

    run_query(Stream, "32. DCG Phrase Matcher Helper", "Use DCG interface `re_match_dcg//2` inside phrase/2.",
              "phrase(re_match_dcg(\"a*b\", Match), \"aaabc\", \"c\")",
              phrase(re_match_dcg("a*b", Match32), "aaabc", "c"),
              ["Match"], [Match32]),

    run_query(Stream, "33. DCG Phrase Matcher with Groups", "Use DCG interface `re_match_dcg//3` with groups inside phrase/2.",
              "phrase(re_match_dcg(\"(a*)b\", Match, Groups), \"aaabc\", \"c\")",
              phrase(re_match_dcg("(a*)b", Match33, Groups33), "aaabc", "c"),
              ["Match", "Groups"], [Match33, Groups33]),

    run_query(Stream, "34. DCG Phrase Matcher with Compiled Pattern", "Use `re_match_dcg//2` with a pre-compiled pattern.",
              "re_compile(\"a*b\", Compiled), phrase(re_match_dcg(Compiled, Match), \"aaabc\", \"c\")",
              (re_compile("a*b", Compiled34), phrase(re_match_dcg(Compiled34, Match34), "aaabc", "c")),
              ["Compiled", "Match"], [Compiled34, Match34]),

    run_query(Stream, "35. DCG Phrase Matcher with Compiled Pattern and Groups", "Use `re_match_dcg//3` with a pre-compiled pattern and group extraction.",
              "re_compile(\"(a*)b\", Compiled), phrase(re_match_dcg(Compiled, Match, Groups), \"aaabc\", \"c\")",
              (re_compile("(a*)b", Compiled35), phrase(re_match_dcg(Compiled35, Match35, Groups35), "aaabc", "c")),
              ["Compiled", "Match", "Groups"], [Compiled35, Match35, Groups35]),

    run_query(Stream, "36. Compilation Cache Matching", "Access and verify the internal compilation cache.",
              "re_clear_cache, re_match(\"c*d\", \"cccd\", Match), regexp_dcg:to_chars(\"c*d\", Key), regexp_dcg:pattern_cache(Key, Goal, GroupCount)",
              (re_clear_cache, re_match("c*d", "cccd", Match36), regexp_dcg:to_chars("c*d", Key36), regexp_dcg:pattern_cache(Key36, Goal36, GroupCount36)),
              ["Match", "Key", "Goal", "GroupCount"], [Match36, Key36, Goal36, GroupCount36]),

    run_query(Stream, "37. Compilation Cache Clearing", "Clear the cache database and verify no patterns remain.",
              "re_clear_cache, re_match(\"c*d\", \"cccd\", Match), re_clear_cache, \\+ regexp_dcg:pattern_cache(_, _, _)",
              (re_clear_cache, re_match("c*d", "cccd", _Match37), re_clear_cache),
              [], []),

    run_query(Stream, "38. Unanchored Match (showing rest of input)", "Match pattern inside input using phrase/3.",
              "phrase((..., re_match_dcg(\"aa\", Match)), \"bbbbaaccccc\", Rest)",
              phrase((..., re_match_dcg("aa", Match38)), "bbbbaaccccc", Rest38),
              ["Match", "Rest"], [Match38, Rest38]),

    run_query(Stream, "39. Unanchored Match (no rest of input)", "Match pattern inside input using phrase/2 (requires matching remaining suffix).",
              "phrase((..., re_match_dcg(\"aa\", Match), ...), \"bbbbaaccccc\")",
              phrase((..., re_match_dcg("aa", Match39), ...), "bbbbaaccccc"),
              ["Match"], [Match39]),

    close(Stream).
