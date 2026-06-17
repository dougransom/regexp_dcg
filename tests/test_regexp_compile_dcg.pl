% translate a regexp ast to a DCG for regexp pattern matching over strings.

:- use_module('../bakage').
:- use_module(pkg(testing)).
:- use_module('../regexp_ast').
:- use_module('../regexp_compile_dcg').
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- dynamic(debug_mode/1).
debug_mode(on).

:- use_module('../regexp_ast').   % your existing front-end



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
    (dformat("Testing re_match_dcg with 'abc' against 'abc'", []),
    phrase(re_match_dcg("abc", Match), "abc"),
    dformat("\nMatch result: ~w", [Match]),
    Match == "abc")).

test("precedence: alternation vs concat",
    (phrase(re_match_dcg("a|bc", Match), "bc"),
    Match == "bc")).

test("precedence: grouping with alternation",
    (phrase(re_match_dcg("(a|b)c", Match), "ac"),
    Match == "ac")).

test("quantifier: greedy star",
    (phrase(re_match_dcg("a*", Match), "aaa"),
    Match == "aaa")).

test("quantifier: plus",
    (phrase(re_match_dcg("a+", Match), "aa"),
    Match == "aa")).

test("quantifier: question matches",
    (phrase(re_match_dcg("a?", Match), "a"),
    Match == "a")).

test("quantifier: question empty",
    (phrase(re_match_dcg("a?", Match), ""),
    Match == "")).

test("quantifier: exact repetition",
    (phrase(re_match_dcg("a{3}", Match), "aaa"),
    Match == "aaa")).

test("quantifier: range repetition",
    (phrase(re_match_dcg("a{2,4}", Match), "aaaa"),
    Match == "aaaa")).

test("capture: single group",
    (phrase(re_match_dcg("(abc)", Match, Groups), "abc"),
    Match == "abc",
    Groups == ["abc"])).

test("capture: nested groups",
    (phrase(re_match_dcg("(a(b)c)", Match, Groups), "abc"),
    Match == "abc",
    Groups == ["abc", "b"])).

test("edge: star on empty string",
    (phrase(re_match_dcg("a*", Match), ""),
    Match == "")).

test("edge: nested stars (a*)*",
    (phrase(re_match_dcg("(a*)*", Match), "a"),
    Match == "a")).

% Test cases for the 8 missing features to verify our current parsing/compiling limits

test("1. character classes: simple",
    (phrase(re_match_dcg("[abc]", Match), "b"),
    Match == "b")).

test("1. character classes: negated",
    (phrase(re_match_dcg("[^abc]", Match), "d"),
    Match == "d")).

test("2. wildcard dot",
    (phrase(re_match_dcg("a.c", Match), "abc"),
    Match == "abc")).

test("3. builtin class: digit",
    (phrase(re_match_dcg("\\d", Match), "5"),
    Match == "5")).

test("3. builtin class: word",
    (phrase(re_match_dcg("\\w", Match), "x"),
    Match == "x")).

test("4. anchor: start of line",
    (phrase(re_match_dcg("^a", Match), "a"),
    Match == "a")).

test("4. anchor: end of line",
    (phrase(re_match_dcg("a$", Match), "a"),
    Match == "a")).

test("5. non-greedy quantifier",
    (phrase(re_match_dcg("a*?", Match), "a"),
    Match == "a")).

test("6. assertion: lookahead",
    (phrase(re_match_dcg("a(?=b)b", Match), "ab"),
    Match == "ab")).

test("7. named group",
    (phrase(re_match_dcg("(?P<id>abc)", Match), "abc"),
    Match == "abc")).

test("8. inline flags",
    (phrase(re_match_dcg("(?i)abc", Match), "ABC"),
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

test("dcg phrase match helper with compiled pattern and groups",
    (re_compile("(a*)b", Compiled),
    phrase(re_match_dcg(Compiled, Match, Groups), "aaabc", "c"),
    Match == "aaab",
    Groups == ["aaa"])).


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

test("unanchored match using phrase/3 (shows rest)",
    (phrase((any_chars, re_match_dcg("aa", Match)), "bbbbaaccccc", Rest),
     Match == "aa",
     Rest == "ccccc")).

test("unanchored match using phrase/2 (no rest)",
    (phrase((any_chars, re_match_dcg("aa", Match), any_chars), "bbbbaaccccc"),
     Match == "aa")).

any_chars --> [].
any_chars --> [_], any_chars.

