:- use_module('../testing').
:- use_module('../../src/pure_regex').
:- use_module('../../src/core/regexp_common').
:- use_module('../../src/core/regexp_expansion').
:- use_module(library(dcgs)).
:- use_module(library(lists)).

% Approach B: Static DCG rule generation via term_expansion
re_rule(ident_rule//0, "^[a-z]+$").
re_rule(ident_match_rule(_Match)//0, "^[a-z]+$").
re_rule(ident_groups_rule(_Match, _Groups)//0, "^([a-z]+)-([0-9]+)$").
re_rule_named(ident_named_rule(_Match, _Named)//0, "^(?P<word>[a-z]+)-(?P<num>[0-9]+)$").

% Helper predicates using literal pattern calls (to be expanded by goal_expansion)
test_call_literal_chars(Rest) :-
    re_match("a*b", "aaabc", Rest).

test_call_literal_atom(Rest) :-
    re_match('a*b', "aaabc", Rest).

test_call_literal_groups(Match, Groups) :-
    re_match_groups("([a-z]+)-([0-9]+)", "foo-42", Match, Groups).

test_call_literal_named(Match, Named) :-
    re_match_named("(?P<key>[a-z]+)=(?P<val>[0-9]+)", "count=123", Match, Named).

test_call_dcg_phrase(Match, Rest) :-
    phrase(re_match("a*b", Match), "aaabc", Rest).

test_call_dynamic(Pattern, Input, Rest) :-
    re_match(Pattern, Input, Rest).

test("Approach A: literal chars pattern matches correctly and bypasses dynamic cache",
    ( re_clear_cache,
      test_call_literal_chars(Rest),
      Rest == "c",
      re_cache_info(Count, _Keys),
      Count == 0
    )).

test("Approach A: literal atom pattern matches correctly and bypasses dynamic cache",
    ( re_clear_cache,
      test_call_literal_atom(Rest),
      Rest == "c",
      re_cache_info(Count, _Keys),
      Count == 0
    )).

test("Approach A: DCG phrase call with literal pattern matches and bypasses cache",
    ( re_clear_cache,
      test_call_dcg_phrase(Match, Rest),
      Match == "aaab",
      Rest == "c",
      re_cache_info(Count, _Keys),
      Count == 0
    )).

test("Approach A: groups and named matchers with literals bypass dynamic cache",
    ( re_clear_cache,
      test_call_literal_groups(MatchG, Groups),
      MatchG == "foo-42",
      Groups == ["foo", "42"],
      test_call_literal_named(MatchN, Named),
      MatchN == "count=123",
      member(key-"count", Named),
      member(val-"123", Named),
      re_cache_info(Count, _Keys),
      Count == 0
    )).

test("Dynamic patterns (variables at compile-time) populate the dynamic cache as expected",
    ( re_clear_cache,
      test_call_dynamic("x+y", "xxxy", Rest),
      Rest == [],
      re_cache_info(Count, Keys),
      Count > 0,
      member("x+y", Keys)
    )).

test("Approach B: re_rule//0 expands into working DCG non-terminal",
    ( phrase(ident_rule, "hello", Rest),
      Rest == []
    )).

test("Approach B: re_rule with Match unifies matched substring",
    ( phrase(ident_match_rule(Match), "testing", Rest),
      Match == "testing",
      Rest == []
    )).

test("Approach B: re_rule with Match and Groups captures substrings",
    ( phrase(ident_groups_rule(Match, Groups), "abc-999", Rest),
      Match == "abc-999",
      Groups == ["abc", "999"],
      Rest == []
    )).

test("Approach B: re_rule_named unifies named group pairs",
    ( phrase(ident_named_rule(Match, Named), "hello-456", Rest),
      Match == "hello-456",
      member(word-"hello", Named),
      member(num-"456", Named),
      Rest == []
    )).

test("Engine mode defaults to tree and detects custom modes",
    ( current_regexp_engine(Engine),
      Engine == tree,
      current_regexp_expansion(ExpMode),
      ExpMode == term
    )).

test("normalize_engine maps aliases correctly",
    ( normalize_engine(rt, E1), E1 == tree,
      normalize_engine(tree, E2), E2 == tree,
      normalize_engine(rational_tree, E3), E3 == tree,
      normalize_engine(dcg, E4), E4 == dcg,
      normalize_engine(backtracking, E5), E5 == dcg,
      normalize_engine(dfa, E6), E6 == dfa
    )).

test("engine hierarchy: global vs static vs dynamic defaults",
    ( current_regexp_engine(Global), Global == tree,
      current_static_engine(Static), Static == tree,
      current_dynamic_engine(Dynamic), Dynamic == tree
    )).

test("static compilation enabled by default",
    ( static_compilation_enabled
    )).

test("dynamic engine routes to dcg when user:regexp_dynamic_engine is dcg",
    ( assertz(user:regexp_dynamic_engine(dcg)),
      re_clear_cache,
      P = "a+b",
      re_match(P, "aab"),
      pattern_cache_info(dcg, DcgCount, _),
      DcgCount == 1,
      pattern_cache_info(tree, TreeCount, _),
      TreeCount == 0,
      retract(user:regexp_dynamic_engine(dcg)),
      re_clear_cache
    )).

test("dynamic engine routes to rt when user:regexp_dynamic_engine is rt",
    ( assertz(user:regexp_dynamic_engine(rt)),
      re_clear_cache,
      P = "c+d",
      re_match(P, "ccd"),
      pattern_cache_info(tree, TreeCount, _),
      TreeCount == 1,
      pattern_cache_info(dcg, DcgCount, _),
      DcgCount == 0,
      retract(user:regexp_dynamic_engine(rt)),
      re_clear_cache
    )).

test("global engine setting user:regexp_engine routes both when not overridden",
    ( assertz(user:regexp_engine(dcg)),
      current_static_engine(StaticE), StaticE == dcg,
      current_dynamic_engine(DynE), DynE == dcg,
      retract(user:regexp_engine(dcg))
    )).

test("overriding static engine leaves dynamic engine unaffected",
    ( assertz(user:regexp_engine(rt)),
      assertz(user:regexp_static_engine(dcg)),
      current_static_engine(StaticE), StaticE == dcg,
      current_dynamic_engine(DynE), DynE == tree,
      retract(user:regexp_static_engine(dcg)),
      retract(user:regexp_engine(rt))
    )).

test("overriding dynamic engine leaves static engine unaffected",
    ( assertz(user:regexp_engine(rt)),
      assertz(user:regexp_dynamic_engine(dcg)),
      current_static_engine(StaticE), StaticE == tree,
      current_dynamic_engine(DynE), DynE == dcg,
      retract(user:regexp_dynamic_engine(dcg)),
      retract(user:regexp_engine(rt))
    )).

test("disabling static compilation with user:regexp_static_compilation(false)",
    ( assertz(user:regexp_static_compilation(false)),
      \+ static_compilation_enabled,
      retract(user:regexp_static_compilation(false)),
      static_compilation_enabled
    )).

test("disabling static compilation with user:regexp_expansion(off)",
    ( assertz(user:regexp_expansion(off)),
      \+ static_compilation_enabled,
      retract(user:regexp_expansion(off)),
      static_compilation_enabled
    )).
