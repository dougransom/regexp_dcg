:- module(test_regexp_compile_shared, [shared_test/3]).

:- use_module(library(dcgs)).

shared_test(Engine, "simple match",
    (phrase(Engine:re_match("abc", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "precedence: alternation vs concat",
    (phrase(Engine:re_match("a|bc", Match), "bc"),
     Match == "bc")).

shared_test(Engine, "precedence: grouping with alternation",
    (phrase(Engine:re_match("(a|b)c", Match), "ac"),
     Match == "ac")).

shared_test(Engine, "quantifier: greedy star",
    (phrase(Engine:re_match("a*", Match), "aaa"),
     Match == "aaa")).

shared_test(Engine, "quantifier: plus",
    (phrase(Engine:re_match("a+", Match), "aa"),
     Match == "aa")).

shared_test(Engine, "quantifier: question matches",
    (phrase(Engine:re_match("a?", Match), "a"),
     Match == "a")).

shared_test(Engine, "quantifier: question empty",
    (phrase(Engine:re_match("a?", Match), ""),
     Match == "")).

shared_test(Engine, "quantifier: exact repetition",
    (phrase(Engine:re_match("a{3}", Match), "aaa"),
     Match == "aaa")).

shared_test(Engine, "quantifier: range repetition",
    (phrase(Engine:re_match("a{2,4}", Match), "aaaa"),
     Match == "aaaa")).

% Capturing groups are ordered by group-number order (left-to-right based on their opening parenthesis).
% Definition: https://docs.oracle.com/javase/tutorial/essential/regex/groups.html
shared_test(Engine, "capture: single group",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_groups("(abc)", _, _), "abc"), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_groups("(abc)", Match, Groups), "abc"),
        Match == "abc",
        Groups == ["abc"]
    )).

% The outer group starts first, followed by the inner group.
shared_test(Engine, "capture: nested groups",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_groups("(a(b)c)", _, _), "abc"), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_groups("(a(b)c)", Match, Groups), "abc"),
        Match == "abc",
        Groups == ["abc", "b"]
    )).

shared_test(Engine, "edge: star on empty string",
    (phrase(Engine:re_match("a*", Match), ""),
     Match == "")).

shared_test(Engine, "edge: nested stars (a*)*",
    (phrase(Engine:re_match("(a*)*", Match), "a"),
     Match == "a")).

shared_test(Engine, "1. character classes: simple",
    (phrase(Engine:re_match("[abc]", Match), "b"),
     Match == "b")).

shared_test(Engine, "1. character classes: negated",
    (phrase(Engine:re_match("[^abc]", Match), "d"),
     Match == "d")).

shared_test(Engine, "2. wildcard dot",
    (phrase(Engine:re_match("a.c", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "3. builtin class: digit",
    (phrase(Engine:re_match("\\d", Match), "5"),
     Match == "5")).

shared_test(Engine, "3. builtin class: word",
    (phrase(Engine:re_match("\\w", Match), "x"),
     Match == "x")).

shared_test(Engine, "4. anchor: start of line",
    (phrase(Engine:re_match("^a", Match), "a"),
     Match == "a")).

shared_test(Engine, "4. anchor: end of line",
    (phrase(Engine:re_match("a$", Match), "a"),
     Match == "a")).

shared_test(Engine, "5. non-greedy quantifier",
    (phrase(Engine:re_match("a*?", Match), "a"),
     Match == "a")).

shared_test(Engine, "6. assertion: lookahead",
    (phrase(Engine:re_match("a(?=b)b", Match), "ab"),
     Match == "ab")).

shared_test(Engine, "7. named group",
    (phrase(Engine:re_match("(?P<id>abc)", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "8. inline flags",
    (phrase(Engine:re_match("(?i)abc", Match), "ABC"),
     Match == "ABC")).

shared_test(Engine, "compile pattern and match",
    (Engine:re_compile("a*b", Compiled),
     phrase(Engine:re_match(Compiled, Match1), "aaab"),
     Match1 == "aaab",
     (   Engine == regexp_dfa ->
         catch(phrase(Engine:re_match_groups(Compiled, _, _), "aaab"), Error, true),
         nonvar(Error),
         Error = error(domain_error(dfa_group_extraction, _), _)
     ;   phrase(Engine:re_match_groups(Compiled, Match2, Groups), "aaab"),
         Match2 == "aaab",
         Groups == []
     ))).

shared_test(Engine, "dcg phrase match helper",
    (phrase(Engine:re_match("a*b", Match), "aaabc", "c"),
     Match == "aaab")).

shared_test(Engine, "dcg phrase match groups helper",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_groups("(a*)b", _, _), "aaabc", _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_groups("(a*)b", Match, Groups), "aaabc", "c"),
        Match == "aaab",
        Groups == ["aaa"]
    )).

shared_test(Engine, "dcg phrase match helper with compiled pattern",
    (Engine:re_compile("a*b", Compiled),
     phrase(Engine:re_match(Compiled, Match), "aaabc", "c"),
     Match == "aaab")).

shared_test(Engine, "dcg phrase match helper with compiled pattern and groups",
    (   Engine == regexp_dfa ->
        Engine:re_compile("(a*)b", Compiled),
        catch(phrase(Engine:re_match_groups(Compiled, _, _), "aaabc", _), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   Engine:re_compile("(a*)b", Compiled),
        phrase(Engine:re_match_groups(Compiled, Match, Groups), "aaabc", "c"),
        Match == "aaab",
        Groups == ["aaa"]
    )).

shared_test(Engine, "compilation cache matches",
    (Engine:re_clear_cache,
     phrase(Engine:re_match("c*d", Match), "cccd"),
     Match == "cccd",
     (   Engine == regexp_dcg ->
         regexp_dcg:to_chars("c*d", Key),
         regexp_dcg:pattern_cache(Key, _, _)
     ;   regexp_dfa:dfa_pattern_cache("c*d", _)
     ))).

shared_test(Engine, "compilation cache clearing",
    (Engine:re_clear_cache,
     phrase(Engine:re_match("c*d", _Match), "cccd"),
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
    (phrase((..., Engine:re_match("aa", Match)), "bbbbaaccccc", Rest),
     Match == "aa",
     Rest == "ccccc")).

shared_test(Engine, "unanchored match using phrase/2 (no rest)",
    (phrase((..., Engine:re_match("aa", Match), ...), "bbbbaaccccc"),
     Match == "aa")).

% 3 top-level capture structures, each nested 4 levels deep.
shared_test(Engine, "captures nested 4 deep (3 top-level)",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_groups("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", _, _), "abcdefghijkl"), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_groups("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", Match, Groups), "abcdefghijkl"),
        Match == "abcdefghijkl",
        Groups == ["abcd", "bcd", "cd", "d", "efgh", "fgh", "gh", "h", "ijkl", "jkl", "kl", "l"]
    )).

shared_test(Engine, "literal match via re_match",
    (phrase(Engine:re_match("abc", Match), "abc"),
     Match == "abc")).

shared_test(Engine, "literal no match via re_match",
    (\+ phrase(Engine:re_match("abc", _), "abd"))).

shared_test(Engine, "word boundary",
    (phrase(Engine:re_match("\\ba\\b", Match), "a"),
     Match == "a")).

shared_test(Engine, "word boundary complex",
    (phrase(Engine:re_match("cat\\b", Match), "cat"),
     Match == "cat")).

shared_test(Engine, "captures nested 4 deep (3 top-level) - match only",
    (phrase(Engine:re_match("(a(b(c(d))))(e(f(g(h))))(i(j(k(l))))", Match), "abcdefghijkl"),
     Match == "abcdefghijkl")).

shared_test(Engine, "named capture: simple",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_named("(?P<id>abc)", _, _), "abc"), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_named("(?P<id>abc)", Match, Named), "abc"),
        Match == "abc",
        Named == [id-"abc"],
        Engine:re_group(Named, id, "abc"),
        \+ Engine:re_group(Named, other, _)
    )).

shared_test(Engine, "named capture: mixed named and unnamed",
    (   Engine == regexp_dfa ->
        catch(phrase(Engine:re_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", _, _), "john middle doe"), Error, true),
        nonvar(Error),
        Error = error(domain_error(dfa_group_extraction, _), _)
    ;   phrase(Engine:re_match_named("(?P<first>[a-z]+) ([a-z]+) (?P<last>[a-z]+)", Match, Named), "john middle doe"),
        Match == "john middle doe",
        Named == [last-"doe", first-"john"],
        Engine:re_group(Named, first, "john"),
        Engine:re_group(Named, last, "doe"),
        \+ Engine:re_group(Named, middle, _)
    )).

shared_test(Engine, "error: unbound pattern raises instantiation_error",
    (catch(phrase(Engine:re_match(_Var, _Match), "abc"), Error, true),
     nonvar(Error),
     Error = error(instantiation_error, _))).

shared_test(Engine, "error: invalid pattern type raises domain_error",
    (catch(phrase(Engine:re_match(123, _Match), "abc"), Error, true),
     nonvar(Error),
     Error = error(domain_error(chars, 123), _))).

