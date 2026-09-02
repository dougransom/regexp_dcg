:- use_module('tests/trealla/trealla_loader').
:- use_module('tests/testing').
:- use_module('src/core/regexp_ast').
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

 test("Test Literal - simple string",
    (   In="abxa",
        phrase(re_token(T),In),
        T=lit("abxa")
        )).

 test("Test Literal - string with a `:`, which should provide three tokens",
    (   In="ab:xa",
        phrase(re_tokens(T),In),
        T = [lit("ab"),colon,lit("xa")]
        )).

 test("Test Literal - literal string followed by a single character and then a postfix operator",
    (   In="xyzabc?d",
        phrase(re_token(T),In,_),
        T=lit("xyzab")
        )).

 test("Test Literal - generate literal string from token",
    (   T=lit("xyzabc"),
        var(Str),
        phrase(re_token(T),Str),
        Str="xyzabc"
        )).

 test("Test escaped",
     (   
        phrase(re_token(escaped(a)),Str),
        Str="\\a",
        phrase(re_token(T),Str),
        T=escaped(a)
        )).
test("Metachars ex escaped",
    (
     phrase(re_tokens(Ts),".^$*+?()[]|{}:,"),
    Ts = [dot,caret,dollar,star,plus,question,lparen,rparen,class([]),pipe,lbrace,rbrace,colon,comma])
).

test("CharClass Tokens: simple class",
    (   phrase(re_tokens(T), "[abc]"),
        T = [class([char(a),char(b),char(c)])]
    )).

test("CharClass Tokens: range",
    (   phrase(re_tokens(T), "[a-z]"),
        T = [class([range(a,z)])]
    )).

test("CharClass Tokens: negated class",
    (   phrase(re_tokens(T), "[^abc]"),
        T = [class(neg([char(a),char(b),char(c)]))]
    )).

 test("リテラルテスト - コロンを含む文字列（3つのトークン）",
    (   In="ab:xa",
        phrase(re_tokens(T),In),
        T = [lit("ab"),colon,lit("xa")]
        )).

 test("リテラルテスト - 1文字と後置演算子が続くリテラル文字列",
    (   In="xyzabc?d",
        phrase(re_token(T),In,_),
        T=lit("xyzab")
        )).

 test("リテラルテスト - トークンからリテラル文字列を生成",
    (   T=lit("xyzabc"),
        var(Str),
        phrase(re_token(T),Str),
        Str="xyzabc"
        )).
