:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module('../../src/regexp_dcg').

main :-
    format("====================================================~n", []),
    format(" Multilingual & Unicode Regular Expression Examples~n", []),
    format("====================================================~n~n", []),

    % 1. French Accented Text
    phrase(re_match_groups("(café)-(crêpe)", Match1, Groups1), "café-crêpe"),
    format("1. French Match: ~s, Groups: ~q~n", [Match1, Groups1]),

    % 2. Greek Text & Range Matching
    phrase(re_match("[α-ω]+", GreekMatch), "αβγδεxyz", RestGreek),
    format("2. Greek Range Match [α-ω]+: ~s, Rest: ~s~n", [GreekMatch, RestGreek]),

    % 3. Chinese (Hanzi) Text
    phrase(re_match_named("(?P<greeting>你好)-(?P<target>世界)", Match3, Named3), "你好-世界"),
    format("3. Chinese Named Match: ~s, Named: ~q~n", [Match3, Named3]),

    % 4. Emoji Character & Quantifier Matching
    phrase(re_match_named("(?P<rocket>🚀+)-(?P<smile>😀+)", Match4, Named4), "🚀🚀-😀😀😀"),
    format("4. Emoji Match: ~s, Named: ~q~n", [Match4, Named4]),

    % 5. Klingon Script & Latinized Klingon Matching
    phrase(re_match("", KlingonScript), " Hol", RestKlingon),
    format("5. Klingon Script (tlhIngan): ~s, Rest: ~s~n", [KlingonScript, RestKlingon]),

    phrase(re_match_groups("(Qapla')! (batlh)", Match5, Groups5), "Qapla'! batlh"),
    format("   Klingon Latinized: ~s, Groups: ~q~n~n", [Match5, Groups5]),
    format("All multilingual examples completed successfully!~n", []).
