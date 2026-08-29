:- use_module('../testing').
:- use_module('../../src/regexp_dcg').
:- use_module('../../src/core/regexp_compile_dfa').
:- use_module(library(lists)).
:- use_module(library(dcgs)).

% 1. French Accented Characters
test("International: French accented character literal match",
    (phrase(regexp_dcg:re_match("café", Match), "café et croissant", Rest),
     Match == "café",
     Rest == " et croissant")).

test("International: French accented character capturing groups",
    (phrase(regexp_dcg:re_match_groups("(café)-(crêpe)", Match, Groups), "café-crêpe"),
     Match == "café-crêpe",
     Groups == ["café", "crêpe"])).

% 2. Greek Characters & Unicode Ranges
test("International: Greek character quantifiers",
    (phrase(regexp_dcg:re_match("α+β+", Match), "αααβββ123", Rest),
     Match == "αααβββ",
     Rest == "123")).

test("International: Greek character class range [α-ω]",
    (phrase(regexp_dcg:re_match("[α-ω]+", Match), "αβγδεxyz", Rest),
     Match == "αβγδε",
     Rest == "xyz")).

% 3. Chinese Characters (CJK)
test("International: Chinese (Hanzi) literal and group matching",
    (phrase(regexp_dcg:re_match_named("(?P<greeting>你好)-(?P<target>世界)", Match, Named), "你好-世界"),
     Match == "你好-世界",
     member(greeting-"你好", Named),
     member(target-"世界", Named))).

% 4. Emoji Character Matching
test("International: Emoji literal and quantifier matching",
    (phrase(regexp_dcg:re_match("🚀+😀+", Match), "🚀🚀😀😀😀!foo", Rest),
     Match == "🚀🚀😀😀😀",
     Rest == "!foo")).

test("International: Emoji named capturing groups",
    (phrase(regexp_dcg:re_match_named("(?P<rocket>🚀+)-(?P<smile>😀+)", Match, Named), "🚀🚀-😀😀😀"),
     Match == "🚀🚀-😀😀😀",
     member(rocket-"🚀🚀", Named),
     member(smile-"😀😀😀", Named))).

% 5. Klingon Language Support (Klingon Script PUA & Latinized)
test("International: Klingon PUA script matching (tlhIngan Hol)",
    (phrase(regexp_dcg:re_match("", Match), " Hol", Rest),
     Match == "",
     Rest == " Hol")).

test("International: Latinized Klingon with glottal stops",
    (phrase(regexp_dcg:re_match_groups("(Qapla')! (batlh)", Match, Groups), "Qapla'! batlh"),
     Match == "Qapla'! batlh",
     Groups == ["Qapla'", "batlh"])).

% 6. DFA Engine Compatibility with International Characters
test("International: DFA engine French and Emoji literal match",
    (phrase(regexp_dfa:re_match("café🚀", Match), "café🚀123", Rest),
     Match == "café🚀",
     Rest == "123")).
