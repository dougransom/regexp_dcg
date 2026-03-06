:- use_module(bakage).
:- use_module(pkg(testing)).
:- use_module(regexp_ast).
:- use_module(library(debug)).
test("Force Fail",false).
test("Force Pass",true).

%DCG Tests
test("Test Dot", 
    (phrase(re_dot,"."),
    phrase(re_dot,".abcde",Cs),
    Cs="abcde"  %double checking Cs is what we expect
    )).

test("Test backslash",
    (phrase(re_backslash,"\\"),
    phrase( ("abc",re_backslash),"abc\\de",Cs),
    Cs="de"  %double checking Cs is what we expect
)).

 test("Test Metachars List", 
    (metachars(Cs),
    Cs=["$","(",")","*","+",".","?","[","\\","]","^","{","|","}"]
    )).
    
%test simple puncutation tokens


test("Parse:Test Not Dot", \+phrase(re_dot,"abc.")).

test("Parse:Test .*", 
    (phrase( (re_dot, re_star), ".*"))).


test("Parse:Postfix Expr", 
    (phrase(re_postfix(L,R),".*")
    )
).

test("Parse:simple character sequence",
    (phrase(re_chars(L),"abc"),
    L="abc")
).

test("Parse:character sequence with metachars",
    (phrase(re_chars(L),"abc\\\\"),
    L="abc\\")
).

test("DCG:string to DCG",
    (phrase(X=re_chars(L),"abc\\\\"),
    )
