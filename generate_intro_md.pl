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

    run_query(Stream, "1. DCG for Literal", "Compile pattern into a DCG and match a string.",
              "pattern_ast(\"abc\", AST), ast_dcg(AST, _S0, _S1, DCG), phrase(DCG, \"abc\")",
              (pattern_ast("abc", AST), ast_dcg(AST, _S0, _S1, DCG), phrase(DCG, "abc")),
              ["AST", "DCG"], [AST, DCG]),

    run_query(Stream, "2. Simple Match", "Basic matching of a literal pattern.",
              "phrase(re_match(\"abc\", Match), \"abc\")",
              phrase(re_match("abc", Match2), "abc"),
              ["Match"], [Match2]),

    run_query(Stream, "3. Alternation Precedence", "Matching either sub-expression in alternation.",
              "phrase(re_match(\"a|bc\", Match), \"bc\")",
              phrase(re_match("a|bc", Match3), "bc"),
              ["Match"], [Match3]),

    run_query(Stream, "4. Grouping with Alternation", "Explicit precedence using grouping parentheses.",
              "phrase(re_match(\"(a|b)c\", Match), \"ac\")",
              phrase(re_match("(a|b)c", Match4), "ac"),
              ["Match"], [Match4]),

    run_query(Stream, "5. Greedy Star Quantifier", "Match zero or more times greedily.",
              "phrase(re_match(\"a*\", Match), \"aaa\")",
              phrase(re_match("a*", Match5), "aaa"),
              ["Match"], [Match5]),

    run_query(Stream, "6. Greedy Plus Quantifier", "Match one or more times greedily.",
              "phrase(re_match(\"a+\", Match), \"aa\")",
              phrase(re_match("a+", Match6), "aa"),
              ["Match"], [Match6]),

    run_query(Stream, "7. Optional Quantifier (Match)", "Match zero or one time greedily (optional matches).",
              "phrase(re_match(\"a?\", Match), \"a\")",
              phrase(re_match("a?", Match7), "a"),
              ["Match"], [Match7]),

    run_query(Stream, "8. Optional Quantifier (Empty)", "Match zero or one time greedily (empty match).",
              "phrase(re_match(\"a?\", Match), \"\")",
              phrase(re_match("a?", Match8), ""),
              ["Match"], [Match8]),

    run_query(Stream, "9. Exact Repetition Quantifier", "Match exactly N times.",
              "phrase(re_match(\"a{3}\", Match), \"aaa\")",
              phrase(re_match("a{3}", Match9), "aaa"),
              ["Match"], [Match9]),

    run_query(Stream, "10. Range Repetition Quantifier", "Match between N and M times greedily.",
              "phrase(re_match(\"a{2,4}\", Match), \"aaaa\")",
              phrase(re_match("a{2,4}", Match10), "aaaa"),
              ["Match"], [Match10]),

    run_query(Stream, "11. Single Group Capture", "Extract substrings captured by groups. Captured groups are returned in group-number order (left-to-right based on the position of their opening parentheses). See: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html",
              "phrase(re_match_groups(\"(abc)\", Match, Groups), \"abc\")",
              phrase(re_match_groups("(abc)", Match11, Groups11), "abc"),
              ["Match", "Groups"], [Match11, Groups11]),

    run_query(Stream, "12. Nested Group Capture", "Extract substrings captured by nested groups. The groups are returned in group-number order (left-to-right based on the position of their opening parentheses), so the outer group comes first. See: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html",
              "phrase(re_match_groups(\"(a(b)c)\", Match, Groups), \"abc\")",
              phrase(re_match_groups("(a(b)c)", Match12, Groups12), "abc"),
              ["Match", "Groups"], [Match12, Groups12]),

    run_query(Stream, "13. Star on Empty String", "Edge case: greedy star matching empty string.",
              "phrase(re_match(\"a*\", Match), \"\")",
              phrase(re_match("a*", Match13), ""),
              ["Match"], [Match13]),

    run_query(Stream, "14. Nested Stars", "Edge case: nested star operator.",
              "phrase(re_match(\"(a*)*\", Match), \"a\")",
              phrase(re_match("(a*)*", Match14), "a"),
              ["Match"], [Match14]),

    run_query(Stream, "15. Character Classes (Simple)", "Match any single character listed in brackets.",
              "phrase(re_match(\"[abc]\", Match), \"b\")",
              phrase(re_match("[abc]", Match15), "b"),
              ["Match"], [Match15]),

    run_query(Stream, "16. Character Classes (Negated)", "Match any single character not listed in brackets.",
              "phrase(re_match(\"[^abc]\", Match), \"d\")",
              phrase(re_match("[^abc]", Match16), "d"),
              ["Match"], [Match16]),

    run_query(Stream, "17. Wildcard Dot", "Match any single character except newline.",
              "phrase(re_match(\"a.c\", Match), \"abc\")",
              phrase(re_match("a.c", Match17), "abc"),
              ["Match"], [Match17]),

    run_query(Stream, "18. Builtin Digit Class", "Match any digit character via `\\d`.",
              "phrase(re_match(\"\\\\d\", Match), \"5\")",
              phrase(re_match("\\d", Match18), "5"),
              ["Match"], [Match18]),

    run_query(Stream, "19. Builtin Word Class", "Match any alphanumeric character plus underscore via `\\w`.",
              "phrase(re_match(\"\\\\w\", Match), \"x\")",
              phrase(re_match("\\w", Match19), "x"),
              ["Match"], [Match19]),

    run_query(Stream, "20. Start-of-Line Anchor", "Match beginning of the input string via `^`.",
              "phrase(re_match(\"^a\", Match), \"a\")",
              phrase(re_match("^a", Match20), "a"),
              ["Match"], [Match20]),

    run_query(Stream, "21. End-of-Line Anchor", "Match end of the input string via `$`.",
              "phrase(re_match(\"a$\", Match), \"a\")",
              phrase(re_match("a$", Match21), "a"),
              ["Match"], [Match21]),

    run_query(Stream, "22. Non-Greedy Quantifier", "Match minimal number of repetitions via `*?`.",
              "phrase(re_match(\"a*?\", Match), \"a\")",
              phrase(re_match("a*?", Match22), "a"),
              ["Match"], [Match22]),

    run_query(Stream, "23. Positive Lookahead Assertion", "Match pattern only if followed by lookahead sub-expression.",
              "phrase(re_match(\"a(?=b)b\", Match), \"ab\")",
              phrase(re_match("a(?=b)b", Match23), "ab"),
              ["Match"], [Match23]),

    run_query(Stream, "24. Named Group Capture", "Syntax support for named capturing groups.",
              "phrase(re_match(\"(?P<id>abc)\", Match), \"abc\")",
              phrase(re_match("(?P<id>abc)", Match24), "abc"),
              ["Match"], [Match24]),

    run_query(Stream, "25. Inline Case-Insensitive Flag", "Enable case-insensitivity using inline flags.",
              "phrase(re_match(\"(?i)abc\", Match), \"ABC\")",
              phrase(re_match("(?i)abc", Match25), "ABC"),
              ["Match"], [Match25]),

    run_query(Stream, "26. Compile and Match", "Manually compile a pattern and execute matching.",
              "re_compile(\"a*b\", Compiled), phrase(re_match(Compiled, Match), \"aaab\")",
              (re_compile("a*b", Compiled26), phrase(re_match(Compiled26, Match26), "aaab")),
              ["Compiled", "Match"], [Compiled26, Match26]),

    run_query(Stream, "27. DCG Phrase Matcher Helper", "Use DCG interface `re_match//2` inside phrase/3.",
              "phrase(re_match(\"a*b\", Match), \"aaabc\", \"c\")",
              phrase(re_match("a*b", Match27), "aaabc", "c"),
              ["Match"], [Match27]),

    run_query(Stream, "28. DCG Phrase Matcher with Groups", "Use DCG interface `re_match_groups//3` with groups inside phrase/3. Captured groups are returned in group-number order (left-to-right based on the position of their opening parentheses). See: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html",
              "phrase(re_match_groups(\"(a*)b\", Match, Groups), \"aaabc\", \"c\")",
              phrase(re_match_groups("(a*)b", Match28, Groups28), "aaabc", "c"),
              ["Match", "Groups"], [Match28, Groups28]),

    run_query(Stream, "29. DCG Phrase Matcher with Compiled Pattern", "Use `re_match//2` with a pre-compiled pattern.",
              "re_compile(\"a*b\", Compiled), phrase(re_match(Compiled, Match), \"aaabc\", \"c\")",
              (re_compile("a*b", Compiled29), phrase(re_match(Compiled29, Match29), "aaabc", "c")),
              ["Compiled", "Match"], [Compiled29, Match29]),

    run_query(Stream, "30. DCG Phrase Matcher with Compiled Pattern and Groups", "Use `re_match_groups//3` with a pre-compiled pattern and group extraction. Captured groups are returned in group-number order (left-to-right based on the position of their opening parentheses). See: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html",
              "re_compile(\"(a*)b\", Compiled), phrase(re_match_groups(Compiled, Match, Groups), \"aaabc\", \"c\")",
              (re_compile("(a*)b", Compiled30), phrase(re_match_groups(Compiled30, Match30, Groups30), "aaabc", "c")),
              ["Compiled", "Match", "Groups"], [Compiled30, Match30, Groups30]),

    run_query(Stream, "31. Compilation Cache Matching", "Access and verify the internal compilation cache.",
              "re_clear_cache, phrase(re_match(\"c*d\", Match), \"cccd\"), regexp_dcg:to_chars(\"c*d\", Key), regexp_dcg:pattern_cache(Key, Goal, GroupCount)",
              (re_clear_cache, phrase(re_match("c*d", Match31), "cccd"), regexp_dcg:to_chars("c*d", Key31), regexp_dcg:pattern_cache(Key31, Goal31, GroupCount31)),
              ["Match", "Key", "Goal", "GroupCount"], [Match31, Key31, Goal31, GroupCount31]),

    run_query(Stream, "32. Compilation Cache Clearing", "Clear the cache database and verify no patterns remain.",
              "re_clear_cache, phrase(re_match(\"c*d\", Match), \"cccd\"), re_clear_cache, \\+ regexp_dcg:pattern_cache(_, _, _)",
              (re_clear_cache, phrase(re_match("c*d", _Match32), "cccd"), re_clear_cache),
              [], []),

    run_query(Stream, "33. Unanchored Match (showing rest of input)", "Match pattern inside input using phrase/3.",
              "phrase((..., re_match(\"aa\", Match)), \"bbbbaaccccc\", Rest)",
              phrase((..., re_match("aa", Match33)), "bbbbaaccccc", Rest33),
              ["Match", "Rest"], [Match33, Rest33]),

    run_query(Stream, "34. Unanchored Match (no rest of input)", "Match pattern inside input using phrase/2 (requires matching remaining suffix).",
              "phrase((..., re_match(\"aa\", Match), ...), \"bbbbaaccccc\")",
              phrase((..., re_match("aa", Match34), ...), "bbbbaaccccc"),
              ["Match"], [Match34]),

    run_query(Stream, "35. Nested Captures 4-Deep (3 Top-Level)", "Extract groups from a pattern of three captures containing nested captures 4 deep. Captured groups are returned in group-number order (left-to-right based on the position of their opening parentheses). Nested groups follow their enclosing group. See: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html",
              "phrase(re_match_groups(\"(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))\", Match, Groups), \"abcdefghijkl\")",
              phrase(re_match_groups("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", Match35, Groups35), "abcdefghijkl"),
              ["Match", "Groups"], [Match35, Groups35]),

    run_query(Stream, "36. Named Capturing Groups Matching", "Match pattern and extract named capturing groups using re_match_named//3 and lookup using re_group/3.",
              "phrase(re_match_named(\"(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)\", Match, Named), \"john middle doe\"), re_group(Named, first, First)",
              (phrase(re_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", Match36, Named36), "john middle doe"), re_group(Named36, first, First36)),
              ["Match", "Named", "First"], [Match36, Named36, First36]),

    close(Stream).
