:- module(test_regexp_compile_shared, [shared_test/3]).

:- use_module(library(dcgs)).

shared_test(Engine, "simple match",
    (phrase(Engine:re_match_dcg("abc", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "precedence: alternation vs concat",
    (phrase(Engine:re_match_dcg("a|bc", Match), "bc"),
     Match == "bc")).

shared_test(Engine, "precedence: grouping with alternation",
    (phrase(Engine:re_match_dcg("(a|b)c", Match), "ac"),
     Match == "ac")).

shared_test(Engine, "quantifier: greedy star",
    (phrase(Engine:re_match_dcg("a*", Match), "aaa"),
     Match == "aaa")).

shared_test(Engine, "quantifier: plus",
    (phrase(Engine:re_match_dcg("a+", Match), "aa"),
     Match == "aa")).

shared_test(Engine, "quantifier: question matches",
    (phrase(Engine:re_match_dcg("a?", Match), "a"),
     Match == "a")).

shared_test(Engine, "quantifier: question empty",
    (phrase(Engine:re_match_dcg("a?", Match), ""),
     Match == "")).

shared_test(Engine, "quantifier: exact repetition",
    (phrase(Engine:re_match_dcg("a{3}", Match), "aaa"),
     Match == "aaa")).

shared_test(Engine, "quantifier: range repetition",
    (phrase(Engine:re_match_dcg("a{2,4}", Match), "aaaa"),
     Match == "aaaa")).

% Capturing groups are ordered by group-number order (left-to-right based on their opening parenthesis).
% Definition: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html
shared_test(Engine, "capture: single group",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_groups("(abc)", "abc", _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_dcg("(abc)", Match, Groups), "abc"),
        Match == "abc",
        Groups == ["abc"]
    )).

% The outer group starts first, followed by the inner group.
shared_test(Engine, "capture: nested groups",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_groups("(a(b)c)", "abc", _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_dcg("(a(b)c)", Match, Groups), "abc"),
        Match == "abc",
        Groups == ["abc", "b"]
    )).

shared_test(Engine, "edge: star on empty string",
    (phrase(Engine:re_match_dcg("a*", Match), ""),
     Match == "")).

shared_test(Engine, "edge: nested stars (a*)*",
    (phrase(Engine:re_match_dcg("(a*)*", Match), "a"),
     Match == "a")).

% Test cases for the 8 missing features to verify our current parsing/compiling limits

shared_test(Engine, "1. character classes: simple",
    (phrase(Engine:re_match_dcg("[abc]", Match), "b"),
     Match == "b")).

shared_test(Engine, "1. character classes: negated",
    (phrase(Engine:re_match_dcg("[^abc]", Match), "d"),
     Match == "d")).

shared_test(Engine, "2. wildcard dot",
    (phrase(Engine:re_match_dcg("a.c", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "3. builtin class: digit",
    (phrase(Engine:re_match_dcg("\\d", Match), "5"),
     Match == "5")).

shared_test(Engine, "3. builtin class: word",
    (phrase(Engine:re_match_dcg("\\w", Match), "x"),
     Match == "x")).

shared_test(Engine, "4. anchor: start of line",
    (phrase(Engine:re_match_dcg("^a", Match), "a"),
     Match == "a")).

shared_test(Engine, "4. anchor: end of line",
    (phrase(Engine:re_match_dcg("a$", Match), "a"),
     Match == "a")).

shared_test(Engine, "5. non-greedy quantifier",
    (phrase(Engine:re_match_dcg("a*?", Match), "a"),
     Match == "a")).

shared_test(Engine, "6. assertion: lookahead",
    (phrase(Engine:re_match_dcg("a(?=b)b", Match), "ab"),
     Match == "ab")).

shared_test(Engine, "7. named group",
    (phrase(Engine:re_match_dcg("(?P<id>abc)", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "8. inline flags",
    (phrase(Engine:re_match_dcg("(?i)abc", Match), "ABC"),
     Match == "ABC")).

shared_test(Engine, "reif compatibility: re_match_t true",
    (Engine:re_match_t("abc", "abc", T),
     T == true)).

shared_test(Engine, "reif compatibility: re_match_t false",
    (Engine:re_match_t("abc", "def", T),
     T == false)).

shared_test(Engine, "reif compatibility: re_match_groups_t true",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_groups_t("(abc)", "abc", _, _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_groups_t("(abc)", "abc", Match, Groups, T),
        T == true,
        Match == "abc",
        Groups == ["abc"]
    )).

shared_test(Engine, "reif compatibility: re_match_groups_t false",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_groups_t("(abc)", "def", _, _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_groups_t("(abc)", "def", Match, Groups, T),
        T == false,
        var(Match),
        var(Groups)
    )).

shared_test(Engine, "compile pattern and match",
    (Engine:re_compile("a*b", Compiled),
     Engine:re_match(Compiled, "aaab", Match1),
     Match1 == "aaab",
     (   Engine == regexp_dfa ->
         catch(Engine:re_match_groups(Compiled, "aaab", _, _), Error, true),
         nonvar(Error),
         Error = error(domain_error(dfa_group_extraction, _), _)
     ;   Engine:re_match_groups(Compiled, "aaab", Match2, Groups),
         Match2 == "aaab",
         Groups == []
     ))).

shared_test(Engine, "compile pattern and reif match",
    (Engine:re_compile("a*b", Compiled),
     Engine:re_match_t(Compiled, "aaab", T1),
     T1 == true,
     Engine:re_match_t(Compiled, "aaac", T2),
     T2 == false)).

shared_test(Engine, "dcg phrase match helper",
    (phrase(Engine:re_match_dcg("a*b", Match), "aaabc", "c"),
     Match == "aaab")).

shared_test(Engine, "dcg phrase match groups helper",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_dcg("(a*)b", _, _), "aaabc", _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_dcg("(a*)b", Match, Groups), "aaabc", "c"),
        Match == "aaab",
        Groups == ["aaa"]
    )).

shared_test(Engine, "dcg phrase match helper with compiled pattern",
    (Engine:re_compile("a*b", Compiled),
     phrase(Engine:re_match_dcg(Compiled, Match), "aaabc", "c"),
     Match == "aaab")).

shared_test(Engine, "dcg phrase match helper with compiled pattern and groups",
    (   Engine == regexp_dfa ->
        Engine:re_compile("(a*)b", Compiled),
        catch(phrase(Engine:re_match_dcg(Compiled, _, _), "aaabc", _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_compile("(a*)b", Compiled),
        phrase(Engine:re_match_dcg(Compiled, Match, Groups), "aaabc", "c"),
        Match == "aaab",
        Groups == ["aaa"]
    )).

shared_test(Engine, "compilation cache matches",
    (Engine:re_clear_cache,
     Engine:re_match("c*d", "cccd", Match),
     Match == "cccd",
     (   Engine == regexp_dcg ->
         regexp_dcg:to_chars("c*d", Key),
         regexp_dcg:pattern_cache(Key, _, _)
     ;   regexp_dfa:dfa_pattern_cache("c*d", _)
     ))).

shared_test(Engine, "compilation cache clearing",
    (Engine:re_clear_cache,
     Engine:re_match("c*d", "cccd", _Match),
     (   Engine == regexp_dcg ->
         regexp_dcg:to_chars("c*d", Key),
         regexp_dcg:pattern_cache(Key, _, _),
         Engine:re_clear_cache,
         \+ regexp_dcg:pattern_cache(Key, _, _)
     ;   regexp_dfa:dfa_pattern_cache("c*d", _),
         Engine:re_clear_cache,
         \+ regexp_dfa:dfa_pattern_cache("c*d", _)
     ))).

shared_test(Engine, "unanchored match using phrase/3 (shows rest)",
    (phrase((..., Engine:re_match_dcg("aa", Match)), "bbbbaaccccc", Rest),
     Match == "aa",
     Rest == "ccccc")).

shared_test(Engine, "unanchored match using phrase/2 (no rest)",
    (phrase((..., Engine:re_match_dcg("aa", Match), ...), "bbbbaaccccc"),
     Match == "aa")).

% 3 top-level capture structures, each nested 4 levels deep. Capturing groups are ordered
% in group-number order (left-to-right based on their opening parenthesis).
% Definition: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html
shared_test(Engine, "captures nested 4 deep (3 top-level)",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_groups("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", "abcdefghijkl", _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_dcg("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", Match, Groups), "abcdefghijkl"),
        Match == "abcdefghijkl",
        Groups == ["abcd", "bcd", "cd", "d", "efgh", "fgh", "gh", "h", "ijkl", "jkl", "kl", "l"]
    )).

shared_test(Engine, "literal match via re_match",
    (Engine:re_match("abc", "abc", Match),
     Match == "abc")).

shared_test(Engine, "literal no match via re_match",
    (\+ Engine:re_match("abc", "abd", _))).

shared_test(Engine, "word boundary",
    (Engine:re_match("\\ba\\b", "a", Match),
     Match == "a")).

shared_test(Engine, "word boundary complex",
    (Engine:re_match("cat\\b", "cat", Match),
     Match == "cat")).

shared_test(Engine, "captures nested 4 deep (3 top-level) - match only",
    (Engine:re_match("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", "abcdefghijkl", Match),
     Match == "abcdefghijkl")).

shared_test(Engine, "named capture: simple",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_named("(?P<id>abc)", "abc", _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_named("(?P<id>abc)", "abc", Match, Named),
        Match == "abc",
        Named == [id-"abc"],
        Engine:re_group(Named, id, "abc"),
        \+ Engine:re_group(Named, other, _)
    )).

shared_test(Engine, "named capture: mixed named and unnamed",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", "john middle doe", _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", "john middle doe", Match, Named),
        Match == "john middle doe",
        Named == [last-"doe", first-"john"],
        Engine:re_group(Named, first, "john"),
        Engine:re_group(Named, last, "doe"),
        \+ Engine:re_group(Named, middle, _)
    )).

shared_test(Engine, "named capture: reified true",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_named_t("(?P<id>abc)", "abc", _, _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_named_t("(?P<id>abc)", "abc", Match, Named, T),
        T == true,
        Match == "abc",
        Named == [id-"abc"]
    )).

shared_test(Engine, "named capture: reified false",
    (   Engine == regexp_dfa ->
        catch(Engine:re_match_named_t("(?P<id>abc)", "def", _, _, _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_match_named_t("(?P<id>abc)", "def", Match, Named, T),
        T == false,
        var(Match),
        var(Named)
    )).


