:- module(regexp_ast, [re_expr//1,re_dot//0, re_caret//0, re_dollar//0, 
        re_star//0, re_plus//0, re_question//0, re_backslash//0, 
        re_pipe//0, re_left_paren//0, re_right_paren//0, 
        re_left_brace//0, re_right_brace//0, re_left_bracket//0, 
        re_char//1,
        re_right_bracket//0, re_metachar//0,metachars/1, re_postfix//2, 
        re_chars//1,re_suffix//1]).
:-use_module(library(dcgs)).
:-use_module(library(reif)).
:- use_module(library(tabling)).

%https://docs.python.org/3/library/re.html#re-syntax


%all metacharacters, in sorted order


metachars_strings(Ss) :- findall(L,phrase(re_metachar,L),Bs),sort(Bs,Ss).

:- table   metachars/1.
metachars(Cs) :- metachars_strings(Ss),phrase(seqq(Ss),Cs).
 
metachar_t(C, T) :-
    metachars(MCs),
    memberd_t(C, MCs, T).

postfix_chars("*+?").

re_dot --> ".". 
re_caret --> "^".
re_dollar --> "$".
re_star --> "*".
re_plus --> "+".
re_question --> "?".
re_backslash --> "\\".
re_pipe --> "|".
re_left_paren --> "(".
re_right_paren --> ")". 
re_left_brace --> "{".
re_right_brace --> "}".
re_left_bracket --> "[".
re_right_bracket --> "]".

re_metachar --> re_dot
    | re_caret
    | re_dollar
    | re_star
    | re_plus
    | re_question
    | re_backslash
    | re_pipe
    | re_left_paren
    | re_right_paren
    | re_left_brace
    | re_right_brace
    | re_left_bracket
    | re_right_bracket.

postfix_char_t(C, T) :-
    postfix_chars(Ps),
    memberd_t(C, Ps, T).



% re_expr(re_dollar) --> re_dollar.
% re_expr(re_dot) --> re_dot.

% re_expr(re_chars([C|Cs])) -->
%     [C],
%     { metachar_t(C, false) },
%     re_chars(Cs).

% re_expr(re_postfix(Sub, Postfix)) --> re_postfix(Sub, Postfix).


re_expr(AST) -->
    re_term(T),
    re_expr_rest(T, AST).


re_expr_rest(Acc, AST) -->
    re_term(T),
    { Acc2 = re_concat(Acc, T) },
    re_expr_rest(Acc2, AST).

re_expr_rest(AST, AST) --> [].

re_term(AST) -->
    re_atom(A),
    (   re_suffix(S)
    ->  { adjust_postfix(A, S, AST) }
    ;   { AST = A }
    ).

adjust_postfix(re_chars(Cs), S, AST) :-
    split_last(Cs, Init, Last),
    AST = re_concat(
              re_chars(Init),
              re_postfix(re_chars([Last]), S)
          ).


split_last([X], [], X).
split_last([H|T], [H|Init], Last) :-
    split_last(T, Init, Last).

re_atom(re_chars(Cs)) --> re_chars(Cs).
re_atom(re_dot)       --> re_dot.
re_atom(re_dollar)    --> re_dollar.


%TODO this is causing infinfite loop when a postfix expression like .* 
%re_expr(re_concat(L,R)) --> re_expr(L), re_expr(R).






re_postfix(re_expr(Sub),re_suffix(Postfix)) --> re_expr(Sub), re_suffix(Postfix).



% Postifix Operators



%toast it re_postfix_expr(Re_Left,Postfix ) -->  re_not_empty(Re_Left), re_postfix(Postfix).


re_suffix(re_star) --> re_star.
re_suffix(re_question) --> re_question.
re_suffix(re_plus) --> re_plus.

re_chars([C|Cs]) -->
    re_char(C),
    (   peek_code(N),
        { postfix_char_t(N, false) }
    ->  re_chars(Cs)
    ;   { Cs = [] }
    ).

peek_code(C, [C|S], [C|S]).
   
 

re_char(C) -->
    [C],
    { metachar_t(C, false) }.   % normal literal

re_char(C) -->
    "\\",                       % escaped metachar
    [C],
    { metachar_t(C, true) }.


% re_char(C) --> [C], {metachars(MCs),  memberd_t(C,MCs,false)}.
% re_char(C) --> re_backslash, [C], {metachars(MCs), memberd_t(C,MCs,true)}.

%represent a sequence of chars as a list
% re_chars([C|Cs]) --> re_char(C), re_chars(Cs). 
% re_chars([]) --> [].

%relate re_chars to a DCG

ast_dcg(re_chars(Chars), Chars  ).


        


