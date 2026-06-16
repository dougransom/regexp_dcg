% Unit tests for the experimental DFA regex compiler and matcher.

:- use_module('../bakage').
:- use_module(pkg(testing)).
:- use_module('../regexp_compile_dfa').
:- use_module(library(debug)).

test("literal match",
    (regexp_dfa:re_match("abc", "abc", Match),
     Match == "abc")).

test("literal no match",
    (\+ regexp_dfa:re_match("abc", "abd", _))).

test("precedence: alternation vs concat",
    (regexp_dfa:re_match("a|bc", "bc", Match1),
     Match1 == "bc",
     regexp_dfa:re_match("a|bc", "a", Match2),
     Match2 == "a")).

test("precedence: grouping with alternation",
    (regexp_dfa:re_match("(a|b)c", "ac", Match1),
     Match1 == "ac",
     regexp_dfa:re_match("(a|b)c", "bc", Match2),
     Match2 == "bc")).

test("quantifier: greedy star",
    (regexp_dfa:re_match("a*", "aaa", Match1),
     Match1 == "aaa",
     regexp_dfa:re_match("a*", "", Match2),
     Match2 == "")).

test("quantifier: plus",
    (regexp_dfa:re_match("a+", "aa", Match1),
     Match1 == "aa",
     \+ regexp_dfa:re_match("a+", "", _))).

test("quantifier: question matches",
    (regexp_dfa:re_match("a?", "a", Match1),
     Match1 == "a",
     regexp_dfa:re_match("a?", "", Match2),
     Match2 == "")).

test("quantifier: exact repetition",
    (regexp_dfa:re_match("a{3}", "aaa", Match),
     Match == "aaa",
     \+ regexp_dfa:re_match("a{3}", "aa", _))).

test("quantifier: range repetition",
    (regexp_dfa:re_match("a{2,4}", "aaaa", Match1),
     Match1 == "aaaa",
     regexp_dfa:re_match("a{2,4}", "aa", Match2),
     Match2 == "aa",
     \+ regexp_dfa:re_match("a{2,4}", "a", _))).

test("character classes: simple",
    (regexp_dfa:re_match("[abc]", "b", Match),
     Match == "b")).

test("character classes: negated",
    (regexp_dfa:re_match("[^abc]", "d", Match),
     Match == "d",
     \+ regexp_dfa:re_match("[^abc]", "a", _))).

test("wildcard dot",
    (regexp_dfa:re_match("a.c", "abc", Match),
     Match == "abc")).

test("builtin class: digit",
    (regexp_dfa:re_match("\\d", "5", Match),
     Match == "5",
     \+ regexp_dfa:re_match("\\d", "x", _))).

test("builtin class: word",
    (regexp_dfa:re_match("\\w", "x", Match),
     Match == "x")).

test("anchor: start of line",
    (regexp_dfa:re_match("^a", "a", Match),
     Match == "a",
     \+ regexp_dfa:re_match("b^a", "ba", _))).

test("anchor: end of line",
    (regexp_dfa:re_match("a$", "a", Match),
     Match == "a",
     \+ regexp_dfa:re_match("a$b", "ab", _))).

test("word boundary",
    (regexp_dfa:re_match("\\ba\\b", "a", Match),
     Match == "a")).

test("word boundary complex",
    (regexp_dfa:re_match("cat\\b", "cat", Match),
     Match == "cat")).

test("non-greedy quantifier (treated same as greedy)",
    (regexp_dfa:re_match("a*?", "a", Match),
     Match == "a")).

test("inline flags (case insensitivity)",
    (regexp_dfa:re_match("(?i)abc", "ABC", Match),
     Match == "ABC")).

test("reif compatibility: re_match_t true",
    (regexp_dfa:re_match_t("abc", "abc", T),
     T == true)).

test("reif compatibility: re_match_t false",
    (regexp_dfa:re_match_t("abc", "abd", T),
     T == false)).

test("compilation cache matches",
    (regexp_dfa:re_clear_cache,
     regexp_dfa:re_match("c*d", "cccd", Match),
     Match == "cccd",
     regexp_dfa:dfa_pattern_cache("c*d", _))).

test("compilation cache clearing",
    (regexp_dfa:re_clear_cache,
     regexp_dfa:re_match("c*d", "cccd", _),
     regexp_dfa:dfa_pattern_cache("c*d", _),
     regexp_dfa:re_clear_cache,
     \+ regexp_dfa:dfa_pattern_cache("c*d", _))).

test("DFA re_match_groups throws domain_error",
    (catch(regexp_dfa:re_match_groups("(abc)", "abc", _, _), Error, true),
     nonvar(Error),
     Error = error(domain_error(dfa_group_extraction, _), _))).

test("DFA re_match_groups_t throws domain_error",
    (catch(regexp_dfa:re_match_groups_t("(abc)", "abc", _, _, _), Error, true),
     nonvar(Error),
     Error = error(domain_error(dfa_group_extraction, _), _))).

test("DFA re_match_dcg prefix matching",
    (phrase(regexp_dfa:re_match_dcg("a*b", Match), "aaabc", "c"),
     Match == "aaab")).

test("DFA re_match_dcg with groups throws domain_error",
    (catch(phrase(regexp_dfa:re_match_dcg("(a*)b", _, _), "aaabc", _), Error, true),
     nonvar(Error),
     Error = error(domain_error(dfa_group_extraction, _), _))).

