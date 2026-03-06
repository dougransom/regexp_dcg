:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(library(debug)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

% test("Force Fail",false).  %uncomment to see the test suites actually are doing something.

test("Force Pass",true).

%DCG Tests
test("Test Dot", 
    (phrase(re_expr(re_dot),"."),
    phrase(re_dot,".abcde",Cs),
    Cs="abcde"  %double checking Cs is what we expect
    )).

test("Test backslash",
    (phrase(re_backslash,"\\"),
    phrase( ("abc",re_backslash),"abc\\de",Cs),
    Cs="de"  %double checking Cs is what we expect
)).

 test("Test Metachars", 
    (metachars(Cs),
    Cs="$()*+.?[\\]^{|}"
    )).
    
%test simple puncutation tokens


test("Parse:Test Not Dot", \+phrase(re_dot,"abc.")).

test("Parse:Test .*", 
    (
        %test internal re_dot and re_star matches
        phrase( (re_dot, re_star), ".*")
        )).


test("Parse:Postfix Star", 
    phrase(re_postfix(L,R),".*")
).

test("Postfix Star", 
    phrase(re_expr(re_postfix(re_expr(re_dot),re_suffix(re_star))),".*")
).


test("Parse:simple character sequence",
    (phrase(re_chars(L),"abc"),
    L="abc")
).

test("Parse:backlash",
    %remember two '\' in a prolog string is one backslash.  So to have a 
    %backlash in a regexp to match a character '\' requires four '\' in a row in a prolog string.

    (phrase(re_chars(L),"\\\\"),
    L="\\")).

test("Parse:bakslash_from_input",
    %just to show how to encode a regexp in a text file or from user input as opposed to Prolog.
    (phrase_from_file(seq(Cs),"backslash.txt"),
    phrase(re_chars(L),Cs),
    L="\\")).

test("Parse:character sequence with metachars",
    (phrase(re_chars(L),"abc\\\\"),
    L="abc\\")
).

test("DCG:string to DCG",
    % reminder \\ in a prog string is one backslash 
    %abc\\\\ in a prolog string should match one backlash in input.
    (phrase(re_chars(L),"abc\\\\"),  
    L="abc\\")
    ).
