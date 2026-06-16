% translate a regexp ast to a DCG for regexp pattern matching over strings.

:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(regexp_compile_dcg).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- dynamic(debug_mode/1).
debug_mode(on).

:- use_module(regexp_ast).   % your existing front-end



set_debug(on)  :- retractall(debug_mode(_)), assertz(debug_mode(on)).
set_debug(off) :- retractall(debug_mode(_)), assertz(debug_mode(off)).

dformat(Format, Args) :-
    debug_mode(on),
    format(Format, Args).

dformat(_Format, _Args) :-
    debug_mode(off).

dformat(Message) :-
    debug_mode(on),
    format('~w~n', [Message]).

dformat(_Message) :-
    debug_mode(off).

test("dcg for literal",
    (pattern_ast("abc", AST),
    dformat("\nAST: ~w", [AST]),
    ast_dcg(AST, _S0, _S1, DCG),
    dformat("\nDCG: ~w", [DCG]),
    dformat("\nTesting DCG phrase...", []),
    phrase(DCG, "abc") -> 
        dformat("\nDCG phrase succeeded", []) ; 
        dformat("\nDCG phrase failed", [])
    )).

test("simple match",
    (dformat("Testing re_match with 'abc' against 'abc'", []),
    re_match("abc", "abc", Match),
    dformat("\nMatch result: ~w", [Match]),
    Match == "abc")).

test("precedence: alternation vs concat",
    (re_match("a|bc", "bc", Match),
    Match == "bc")).

test("precedence: grouping with alternation",
    (re_match("(a|b)c", "ac", Match),
    Match == "ac")).

test("quantifier: greedy star",
    (re_match("a*", "aaa", Match),
    Match == "aaa")).

test("quantifier: plus",
    (re_match("a+", "aa", Match),
    Match == "aa")).

test("quantifier: question matches",
    (re_match("a?", "a", Match),
    Match == "a")).

test("quantifier: question empty",
    (re_match("a?", "", Match),
    Match == "")).

test("quantifier: exact repetition",
    (re_match("a{3}", "aaa", Match),
    Match == "aaa")).

test("quantifier: range repetition",
    (re_match("a{2,4}", "aaaa", Match),
    Match == "aaaa")).

test("capture: single group",
    (re_match_groups("(abc)", "abc", Match, Groups),
    Match == "abc",
    Groups == ["abc"])).

test("capture: nested groups",
    (re_match_groups("(a(b)c)", "abc", Match, Groups),
    Match == "abc",
    Groups == ["abc", "b"])).

test("edge: star on empty string",
    (re_match("a*", "", Match),
    Match == "")).

test("edge: nested stars (a*)*",
    (re_match("(a*)*", "a", Match),
    Match == "a")).

% Test cases for the 8 missing features to verify our current parsing/compiling limits

test("1. character classes: simple",
    (re_match("[abc]", "b", Match),
    Match == "b")).

test("1. character classes: negated",
    (re_match("[^abc]", "d", Match),
    Match == "d")).

test("2. wildcard dot",
    (re_match("a.c", "abc", Match),
    Match == "abc")).

test("3. builtin class: digit",
    (re_match("\\d", "5", Match),
    Match == "5")).

test("3. builtin class: word",
    (re_match("\\w", "x", Match),
    Match == "x")).

test("4. anchor: start of line",
    (re_match("^a", "a", Match),
    Match == "a")).

test("4. anchor: end of line",
    (re_match("a$", "a", Match),
    Match == "a")).

test("5. non-greedy quantifier",
    (re_match("a*?", "a", Match),
    Match == "a")).

test("6. assertion: lookahead",
    (re_match("a(?=b)b", "ab", Match),
    Match == "ab")).

test("7. named group",
    (re_match("(?P<id>abc)", "abc", Match),
    Match == "abc")).

test("8. inline flags",
    (re_match("(?i)abc", "ABC", Match),
    Match == "ABC")).

test("reif compatibility: re_match_t true",
    (re_match_t("abc", "abc", T),
    T == true)).

test("reif compatibility: re_match_t false",
    (re_match_t("abc", "def", T),
    T == false)).

test("reif compatibility: re_match_groups_t true",
    (re_match_groups_t("(abc)", "abc", Match, Groups, T),
    T == true,
    Match == "abc",
    Groups == ["abc"])).

test("reif compatibility: re_match_groups_t false",
    (re_match_groups_t("(abc)", "def", Match, Groups, T),
    T == false,
    var(Match),
    var(Groups))).

test("compile pattern and match",
    (re_compile("a*b", Compiled),
    re_match(Compiled, "aaab", Match1),
    Match1 == "aaab",
    re_match_groups(Compiled, "aaab", Match2, Groups),
    Match2 == "aaab",
    Groups == [])).

test("compile pattern and reif match",
    (re_compile("a*b", Compiled),
    re_match_t(Compiled, "aaab", T1),
    T1 == true,
    re_match_t(Compiled, "aaac", T2),
    T2 == false)).

test("dcg phrase match helper",
    (phrase(re_match_dcg("a*b", Match), "aaabc", "c"),
    Match == "aaab")).

test("dcg phrase match groups helper",
    (phrase(re_match_dcg("(a*)b", Match, Groups), "aaabc", "c"),
    Match == "aaab",
    Groups == ["aaa"])).

test("dcg phrase match helper with compiled pattern",
    (re_compile("a*b", Compiled),
    phrase(re_match_dcg(Compiled, Match), "aaabc", "c"),
    Match == "aaab")).

test("compilation cache matches",
    (re_clear_cache,
    re_match("c*d", "cccd", Match),
    Match == "cccd",
    % Check that the pattern exists in the cache database
    regexp_dcg:to_chars("c*d", Key),
    regexp_dcg:pattern_cache(Key, _, _))).

test("compilation cache clearing",
    (re_clear_cache,
    re_match("c*d", "cccd", _Match),
    regexp_dcg:to_chars("c*d", Key),
    regexp_dcg:pattern_cache(Key, _, _),
    re_clear_cache,
    \+ regexp_dcg:pattern_cache(Key, _, _))).
