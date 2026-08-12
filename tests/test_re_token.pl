:- use_module('../bakage').
:- use_module(pkg(testing)).
:- use_module('../regexp_ast').
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
        %test relation both ways, String and token
        phrase(re_token(escaped(a)),Str),
        Str="\\a",
        phrase(re_token(T),Str),
        T=escaped(a)
        )).
test("Metachars ex escaped",
     %test by converting a string of metachars to tokens and back to strings again
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

% =============================================================================
% 日本語テストケース (Japanese Language Test Cases)
% =============================================================================

test("リテラルテスト - コロンを含む文字列（3つのトークン）",
    (   In="あい:うえ",
        phrase(re_tokens(T),In),
        T = [lit("あい"),colon,lit("うえ")]
    )).

test("リテラルテスト - 1文字と後置演算子が続くリテラル文字列",
    (   In="あいうえお?か",
        phrase(re_token(T),In,_),
        T=lit("あいうえ")
    )).

test("リテラルテスト - トークンからリテラル文字列を生成",
    (   T=lit("あいうえおか"),
        var(Str),
        phrase(re_token(T),Str),
        Str="あいうえおか"
    )).
