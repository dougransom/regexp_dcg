/**
  Provides a Deterministic Finite Automaton (DFA) based regular expression engine.

  This module compiles regular expressions to an NFA structure and matches them
  using a DFA simulation. Note that group extraction is not supported by the DFA engine
  and will raise a domain error.

  This module is experimental, for comparing performance vs the DCG-based engine. This 
  module may be deprecated in the future.

  This module has been completely written by Google Antigravity and no human review of the 
   code has been performed. 

  For the list of supported regular expression patterns, see the module documentation
  for `regexp_dcg` (in [regexp_dcg.pl](file:///home/doug/code/regexp/regexp_dcg.pl)).
*/
:- module(regexp_dfa, [
    re_match//1,
    re_match//2,
    re_match_groups//3,
    re_match_named//3,
    re_match/2,
    re_match/3,
    re_match_groups/4,
    re_match_groups/5,
    re_match_named/4,
    re_match_named/5,
    re_group/3,
    re_compile/2,
    re_clear_cache/0,
    re_cache_info/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(library(clpz)).
:- use_module(regexp_ast, [re_ast_chars/3, is_ast/1]).
:- use_module(regexp_common).

:- dynamic(dfa_pattern_cache/2).



%% re_match(+Pattern, ?Chars)
re_match(Pattern, Chars) :-
    re_match(Pattern, Chars, []).

%% re_match(+Pattern, ?Chars, -Rest)
% Direct 3-arg matcher and DCG //1 matcher
re_match(Pattern, Chars, Rest) :-
    phrase(re_match(Pattern, _Match), Chars, Rest).

%% re_match(+Pattern, -Match)//
% DCG //2 matcher (expanded to 4 args)
re_match(Pattern, Match, L0, L) :-
    nonvar(Pattern),
    Pattern = nfa(Start, Accept, States, Transitions),
    !,
    append(Match, L, L0),
    dfa_match_chars(nfa(Start, Accept, States, Transitions), Match).
re_match(Pattern, Match, L0, L) :-
    (   (nonvar(Pattern), dfa_pattern_cache(Pattern, NFA)) ->
        true
    ;   pattern_ast(Pattern, AST),
        compile_ast_nfa(AST, NFA),
        (   (list_si(Pattern) ; atom_si(Pattern)) ->
            assertz(dfa_pattern_cache(Pattern, NFA))
        ;   true
        )
    ),
    append(Match, L, L0),
    dfa_match_chars(NFA, Match).

dfa_match_chars(NFA, Match) :-
    to_chars(Match, Chars),
    dfa_match(NFA, Chars).

%% re_match_groups(+Pattern, ?Chars, -Match, -Groups)
re_match_groups(Pattern, Chars, Match, Groups) :-
    re_match_groups(Pattern, Chars, Match, Groups, []).

%% re_match_groups(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
% Direct 5-arg matcher and DCG //3 expanded matcher.
re_match_groups(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        to_chars(Arg2, Input),
        phrase(re_match_groups_dcg(Pattern, Arg3, Arg4), Input, Arg5)
    ;   phrase(re_match_groups_dcg(Pattern, Arg2, Arg3), Arg4, Arg5)
    ).

re_match_groups_dcg(Pattern, _Match, _Groups), _S --> _S,
    { nonvar(Pattern), Pattern = nfa(Start, Accept, States, Transitions) },
    !,
    { domain_error(dfa_group_extraction, nfa(Start, Accept, States, Transitions)) }.
re_match_groups_dcg(Pattern, _Match, _Groups), _S --> _S,
    { domain_error(dfa_group_extraction, Pattern) }.

%% re_match_named(+Pattern, ?Chars, -Match, -NamedGroups)
re_match_named(Pattern, Chars, Match, NamedGroups) :-
    re_match_named(Pattern, Chars, Match, NamedGroups, []).

%% re_match_named(+Pattern, ?Arg2, ?Arg3, ?Arg4, ?Arg5)
% Direct 5-arg matcher and DCG //3 expanded matcher.
re_match_named(Pattern, Arg2, Arg3, Arg4, Arg5) :-
    (   (nonvar(Arg2), (list_si(Arg2) ; atom_si(Arg2))) ->
        to_chars(Arg2, Input),
        phrase(re_match_named_dcg(Pattern, Arg3, Arg4), Input, Arg5)
    ;   phrase(re_match_named_dcg(Pattern, Arg2, Arg3), Arg4, Arg5)
    ).

re_match_named_dcg(Pattern, _Match, _NamedGroups), _S --> _S,
    { nonvar(Pattern), Pattern = nfa(Start, Accept, States, Transitions) },
    !,
    { domain_error(dfa_group_extraction, nfa(Start, Accept, States, Transitions)) }.
re_match_named_dcg(Pattern, _Match, _NamedGroups), _S --> _S,
    { domain_error(dfa_group_extraction, Pattern) }.

%% re_compile(+Pattern, -Compiled)
%
% Compile the regular expression `Pattern` into a reusable NFA structure.
re_compile(Pattern, NFA) :-
    pattern_ast(Pattern, AST),
    compile_ast_nfa(AST, NFA).

%% re_clear_cache
%
% Clear all compiled patterns currently stored in the dynamic `dfa_pattern_cache/2` database.
re_clear_cache :-
    retractall(dfa_pattern_cache(_, _)).

%% re_cache_info(-Count, -Keys)
%
% Unifies `Count` with the total number of compiled patterns currently in the cache,
% and `Keys` with the list of cached pattern key strings.
re_cache_info(Count, Keys) :-
    findall(Key, dfa_pattern_cache(Key, _), Keys),
    length(Keys, Count).



% Compile AST to NFA: starts fresh states at 2 (0=Start, 1=Accept)
compile_ast_nfa(AST, nfa(Start, Accept, Trans, Eps)) :-
    Start = 0,
    Accept = 1,
    ast_nfa(AST, [], Start, Accept, Trans, Eps, 2, _).

/* ---------- NFA Construction ---------- */

ast_nfa(lit([]), _, Start, Accept, [], [eps(Start, Accept, always)], SIn, SIn).
ast_nfa(lit([C|Cs]), Flags, Start, Accept, Trans, [], SIn, SOut) :-
    (   member(case_insensitive, Flags) ->
        chars_nfa_ci([C|Cs], Start, Accept, Trans, SIn, SOut)
    ;   chars_nfa([C|Cs], Start, Accept, Trans, SIn, SOut)
    ).
ast_nfa(escaped(C), Flags, Start, Accept, [trans(Start, Cond, Accept)], [], SIn, SIn) :-
    (   member(case_insensitive, Flags) ->
        Cond = char_ci(C)
    ;   Cond = char(C)
    ).
ast_nfa(dot, _, Start, Accept, [trans(Start, any, Accept)], [], SIn, SIn).
ast_nfa(class(Items), Flags, Start, Accept, [trans(Start, Cond, Accept)], [], SIn, SIn) :-
    (   member(case_insensitive, Flags) ->
        Cond = class_ci(Items)
    ;   Cond = class(Items)
    ).
ast_nfa(builtin(Class), _, Start, Accept, [trans(Start, builtin(Class), Accept)], [], SIn, SIn).
ast_nfa(anchor(bol), _, Start, Accept, [], [eps(Start, Accept, bol)], SIn, SIn).
ast_nfa(anchor(eol), _, Start, Accept, [], [eps(Start, Accept, eol)], SIn, SIn).
ast_nfa(boundary(B), _, Start, Accept, [], [eps(Start, Accept, boundary(B))], SIn, SIn).
ast_nfa(group(Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(capture(Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(named_capture(_, Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(flags(_), _, Start, Accept, [], [eps(Start, Accept, always)], SIn, SIn).
ast_nfa(flags(FlagsStr, Sub), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    parse_flags(FlagsStr, NewFlags),
    append(NewFlags, Flags, CombinedFlags),
    ast_nfa(Sub, CombinedFlags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(or(A, B), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    AStart #= SIn,
    AAccept #= SIn + 1,
    BStart #= SIn + 2,
    BAccept #= SIn + 3,
    SIn1 #= SIn + 4,
    ast_nfa(A, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut1),
    ast_nfa(B, Flags, BStart, BAccept, TransB, EpsB, SOut1, SOut),
    append(TransA, TransB, Trans),
    append(EpsA, EpsB, EpsSub),
    Eps = [eps(Start, AStart, always),
           eps(Start, BStart, always),
           eps(AAccept, Accept, always),
           eps(BAccept, Accept, always) | EpsSub].
ast_nfa(concat(A, B), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    flatten_concat(concat(A, B), Flat),
    factors_nfa(Flat, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(concat(List), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    list_si(List),
    flatten_list(List, Flat),
    factors_nfa(Flat, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(postfix(Expr, star), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    AStart #= SIn,
    AAccept #= SIn + 1,
    SIn1 #= SIn + 2,
    ast_nfa(Expr, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut),
    append(TransA, [], Trans),
    append(EpsA, [
        eps(Start, AStart, always),
        eps(Start, Accept, always),
        eps(AAccept, AStart, always),
        eps(AAccept, Accept, always)
    ], Eps).
ast_nfa(postfix(Expr, plus), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    AStart #= SIn,
    AAccept #= SIn + 1,
    SIn1 #= SIn + 2,
    ast_nfa(Expr, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut),
    append(TransA, [], Trans),
    append(EpsA, [
        eps(Start, AStart, always),
        eps(AAccept, AStart, always),
        eps(AAccept, Accept, always)
    ], Eps).
ast_nfa(postfix(Expr, question), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    AStart is SIn,
    AAccept is SIn + 1,
    SIn1 is SIn + 2,
    ast_nfa(Expr, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut),
    append(TransA, [], Trans),
    append(EpsA, [
        eps(Start, AStart, always),
        eps(Start, Accept, always),
        eps(AAccept, Accept, always)
    ], Eps).
ast_nfa(postfix(Expr, lazy(Op)), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    ast_nfa(postfix(Expr, Op), Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(quant(Expr, Q), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    (   Q = lazy(Q0) -> Q1 = Q0 ; Q1 = Q ),
    expand_quant(Expr, Q1, ExpandedAST),
    ast_nfa(ExpandedAST, Flags, Start, Accept, Trans, Eps, SIn, SOut).

% Bounded repetitions unrolling
expand_quant(Expr, mn(M, N), Expanded) :-
    (   N == inf ->
        expand_min_inf(Expr, M, Expanded)
    ;   integer(N) ->
        expand_min_max(Expr, M, N, Expanded)
    ).

expand_min_inf(Expr, 0, postfix(Expr, star)).
expand_min_inf(Expr, M, concat(Expr, Sub)) :-
    M > 0,
    M1 is M - 1,
    expand_min_inf(Expr, M1, Sub).

expand_min_max(_Expr, 0, 0, lit([])).
expand_min_max(Expr, 0, N, concat(postfix(Expr, question), Sub)) :-
    N > 0,
    N1 is N - 1,
    expand_min_max(Expr, 0, N1, Sub).
expand_min_max(Expr, M, N, concat(Expr, Sub)) :-
    M > 0,
    M1 is M - 1,
    N1 is N - 1,
    expand_min_max(Expr, M1, N1, Sub).

% Flatting con-cat helper
flatten_concat(concat(A, B), Flat) :-
    flatten_concat(A, FlatA),
    flatten_concat(B, FlatB),
    append(FlatA, FlatB, Flat).
flatten_concat(concat(List), Flat) :-
    list_si(List),
    flatten_list(List, Flat).
flatten_concat(Expr, [Expr]) :-
    dif(Expr, concat(_)),
    dif(Expr, concat(_, _)).

flatten_list([], []).
flatten_list([H|T], Flat) :-
    flatten_concat(H, FlatH),
    flatten_list(T, FlatT),
    append(FlatH, FlatT, Flat).

% Threading factors with flags
factors_nfa([], _, Start, Accept, [], [eps(Start, Accept, always)], S, S).
factors_nfa([F], Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    ast_nfa(F, Flags, Start, Accept, Trans, Eps, SIn, SOut).
factors_nfa([F|Fs], Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    Fs = [_|_],
    (   F = flags(NewFlagsStr) ->
        parse_flags(NewFlagsStr, NewFlags),
        append(NewFlags, Flags, CombinedFlags),
        factors_nfa(Fs, CombinedFlags, Start, Accept, Trans, Eps, SIn, SOut)
    ;   Mid is SIn,
        SIn1 is SIn + 1,
        ast_nfa(F, Flags, Start, Mid, Trans1, Eps1, SIn1, SOut1),
        factors_nfa(Fs, Flags, Mid, Accept, Trans2, Eps2, SOut1, SOut),
        append(Trans1, Trans2, Trans),
        append(Eps1, Eps2, Eps)
    ).


% Compile list of characters to NFA chain
chars_nfa([], S, S, [], S, S).
chars_nfa([C|Cs], Start, Accept, Trans, SIn, SOut) :-
    (   Cs = [] ->
        Trans = [trans(Start, char(C), Accept)],
        SOut = SIn
    ;   Mid is SIn,
        SIn1 is SIn + 1,
        Trans = [trans(Start, char(C), Mid) | Trans1],
        chars_nfa(Cs, Mid, Accept, Trans1, SIn1, SOut)
    ).

chars_nfa_ci([], S, S, [], S, S).
chars_nfa_ci([C|Cs], Start, Accept, Trans, SIn, SOut) :-
    (   Cs = [] ->
        Trans = [trans(Start, char_ci(C), Accept)],
        SOut = SIn
    ;   Mid is SIn,
        SIn1 is SIn + 1,
        Trans = [trans(Start, char_ci(C), Mid) | Trans1],
        chars_nfa_ci(Cs, Mid, Accept, Trans1, SIn1, SOut)
    ).

/* ---------- DFA Matcher (NFA Simulation) ---------- */

dfa_match(nfa(Start, Accept, Trans, Eps), Chars) :-
    (   Chars = [] ->
        epsilon_closure([Start], Eps, Closure, start, end),
        member(Accept, Closure)
    ;   Chars = [C|_] ->
        epsilon_closure([Start], Eps, Closure0, start, C),
        dfa_loop(Chars, Closure0, Trans, Eps, Accept)
    ).

dfa_loop([], State, _, _, Accept) :-
    member(Accept, State).
dfa_loop([C|Cs], State, Trans, Eps, Accept) :-
    nfa_move(State, C, Trans, MoveStates),
    (   Cs = [] -> NextC = end ; Cs = [NextC|_] ),
    epsilon_closure(MoveStates, Eps, Closure, C, NextC),
    Closure \== [],
    dfa_loop(Cs, Closure, Trans, Eps, Accept).

nfa_move(DFAState, Char, Transitions, NextStates) :-
    findall(To, (
        member(From, DFAState),
        member(trans(From, Cond, To), Transitions),
        match_cond(Cond, Char)
    ), NextStatesUnsorted),
    sort(NextStatesUnsorted, NextStates).

% Epsilon Closure with Prev/Curr character context
epsilon_closure(States, Epsilons, Closure, Prev, Curr) :-
    epsilon_closure_loop(States, Epsilons, States, Closure, Prev, Curr).

epsilon_closure_loop([], _, Closure, Closure, _, _).
epsilon_closure_loop([S|Ss], Epsilons, Acc, Closure, Prev, Curr) :-
    findall(To, (
        member(eps(S, To, Cond), Epsilons),
        \+ member(To, Acc),
        check_eps_cond(Cond, Prev, Curr)
    ), Reached),
    (   Reached = [] ->
        epsilon_closure_loop(Ss, Epsilons, Acc, Closure, Prev, Curr)
    ;   append(Acc, Reached, Acc1),
        append(Ss, Reached, Ss1),
        epsilon_closure_loop(Ss1, Epsilons, Acc1, Closure, Prev, Curr)
    ).

/* ---------- Match conditions ---------- */

match_cond(char(C), Char) :-
    C == Char.
match_cond(char_ci(C), Char) :-
    char_equal_ci(C, Char).
match_cond(any, _).
match_cond(class(Items), Char) :-
    match_class(Items, Char).
match_cond(class_ci(Items), Char) :-
    match_class_ci(Items, Char).
match_cond(builtin(Class), Char) :-
    match_builtin(Class, Char).

check_eps_cond(always, _, _).
check_eps_cond(bol, Prev, _) :-
    Prev == start.
check_eps_cond(eol, _, Curr) :-
    Curr == end.
check_eps_cond(boundary(word), Prev, Curr) :-
    is_word_char(Prev, W1),
    is_word_char(Curr, W2),
    W1 \== W2.
check_eps_cond(boundary(not_word), Prev, Curr) :-
    is_word_char(Prev, W1),
    is_word_char(Curr, W2),
    W1 == W2.

is_word_char(start, false).
is_word_char(end, false).
is_word_char(C, W) :-
    C \== start,
    C \== end,
    (   match_builtin(word, C) ->
        W = true
    ;   W = false
    ).


