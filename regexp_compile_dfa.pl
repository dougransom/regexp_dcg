/**
  Provides a Deterministic Finite Automaton (DFA) based regular expression engine.

  This module compiles regular expressions to an NFA structure and matches them
  using a DFA simulation. Note that group extraction is not supported by the DFA engine
  and will raise a domain error.
*/
:- module(regexp_dfa, [
    re_match/3,
    re_match_t/3,
    re_match_groups/4,
    re_match_groups_t/5,
    re_compile/2,
    re_match_dcg//2,
    re_match_dcg//3,
    re_clear_cache/0
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(regexp_ast, [re_ast_chars/3]).

:- dynamic(dfa_pattern_cache/2).

%% re_match(+Pattern, +Input, -Match)
%
% Match the regular expression `Pattern` against `Input`.
% `Match` is unified with the matched substring of `Input`.
re_match(Pattern, Input, Match) :-
    to_chars(Input, Chars),
    (   Pattern = nfa(_, _, _, _) ->
        NFA = Pattern
    ;   dfa_pattern_cache(Pattern, NFA) ->
        true
    ;   pattern_ast(Pattern, AST),
        compile_ast_nfa(AST, NFA),
        (   (list_si(Pattern) ; atom_si(Pattern)) ->
            assertz(dfa_pattern_cache(Pattern, NFA))
        ;   true
        )
    ),
    dfa_match(NFA, Chars),
    Match = Input.

%% re_match_t(+Pattern, +Input, ?Truth)
%
% Reified matching. `Truth` is unified with `true` if `Pattern` matches `Input`, and `false` otherwise.
re_match_t(Pattern, Input, T) :-
    (   re_match(Pattern, Input, _) ->
        T = true
    ;   T = false
    ).

%% re_match_groups(+Pattern, +Input, -Match, -Groups)
%
% Match the regular expression `Pattern` against `Input`.
% Note: Capturing groups are not supported by the DFA engine and will raise a domain error.
re_match_groups(Pattern, _Input, _Match, _Groups) :-
    domain_error(dfa_group_extraction, Pattern).

%% re_match_groups_t(+Pattern, +Input, -Match, -Groups, ?Truth)
%
% Reified version of `re_match_groups/4`.
% Note: Capturing groups are not supported by the DFA engine and will raise a domain error.
re_match_groups_t(Pattern, _Input, _Match, _Groups, _T) :-
    domain_error(dfa_group_extraction, Pattern).

%% re_match_dcg(+Pattern, -Match)//
%
% DCG non-terminal prefix matcher. Matches a prefix of the input sequence
% that conforms to the regular expression `Pattern`, unifying it with `Match`.
re_match_dcg(Pattern, Match, L0, L) :-
    append(Match, L, L0),
    re_match(Pattern, Match, Match).

%% re_match_dcg(+Pattern, -Match, -Groups)//
%
% DCG non-terminal prefix matcher.
% Note: Capturing groups are not supported by the DFA engine and will raise a domain error.
re_match_dcg(Pattern, _Match, _Groups) -->
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

% Helper: convert pattern to AST
pattern_ast(AST, AST) :-
    is_ast(AST),
    !.
pattern_ast(Pattern, AST) :-
    to_chars(Pattern, Chars),
    phrase(re_ast_chars(AST), Chars).

is_ast(lit(_)).
is_ast(class(_)).
is_ast(anchor(_)).
is_ast(boundary(_)).
is_ast(group(_)).
is_ast(capture(_)).
is_ast(lookahead(_)).
is_ast(neg_lookahead(_)).
is_ast(quant(_, _)).
is_ast(postfix(_, _)).
is_ast(star(_)).
is_ast(plus(_)).
is_ast(maybe(_)).
is_ast(concat(_)).
is_ast(concat(_, _)).
is_ast(or(_, _)).
is_ast(escaped(_)).
is_ast(dot).
is_ast(named_capture(_, _)).
is_ast(flags(_)).
is_ast(flags(_, _)).

% Compile AST to NFA: starts fresh states at 2 (0=Start, 1=Accept)
compile_ast_nfa(AST, nfa(Start, Accept, Trans, Eps)) :-
    Start = 0,
    Accept = 1,
    ast_nfa(AST, [], Start, Accept, Trans, Eps, 2, _).

/* ---------- NFA Construction ---------- */

ast_nfa(lit([]), _, Start, Accept, [], [eps(Start, Accept, always)], SIn, SIn) :- !.
ast_nfa(lit([C|Cs]), Flags, Start, Accept, Trans, [], SIn, SOut) :-
    !,
    (   member(case_insensitive, Flags) ->
        chars_nfa_ci([C|Cs], Start, Accept, Trans, SIn, SOut)
    ;   chars_nfa([C|Cs], Start, Accept, Trans, SIn, SOut)
    ).
ast_nfa(escaped(C), Flags, Start, Accept, [trans(Start, Cond, Accept)], [], SIn, SIn) :-
    !,
    (   member(case_insensitive, Flags) ->
        Cond = char_ci(C)
    ;   Cond = char(C)
    ).
ast_nfa(dot, _, Start, Accept, [trans(Start, any, Accept)], [], SIn, SIn) :- !.
ast_nfa(class(Items), Flags, Start, Accept, [trans(Start, Cond, Accept)], [], SIn, SIn) :-
    !,
    (   member(case_insensitive, Flags) ->
        Cond = class_ci(Items)
    ;   Cond = class(Items)
    ).
ast_nfa(builtin(Class), _, Start, Accept, [trans(Start, builtin(Class), Accept)], [], SIn, SIn) :- !.
ast_nfa(anchor(bol), _, Start, Accept, [], [eps(Start, Accept, bol)], SIn, SIn) :- !.
ast_nfa(anchor(eol), _, Start, Accept, [], [eps(Start, Accept, eol)], SIn, SIn) :- !.
ast_nfa(boundary(B), _, Start, Accept, [], [eps(Start, Accept, boundary(B))], SIn, SIn) :- !.
ast_nfa(group(Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(capture(Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(named_capture(_, Inner), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    ast_nfa(Inner, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(flags(_), _, Start, Accept, [], [eps(Start, Accept, always)], SIn, SIn) :- !.
ast_nfa(flags(FlagsStr, Sub), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    parse_flags(FlagsStr, NewFlags),
    append(NewFlags, Flags, CombinedFlags),
    ast_nfa(Sub, CombinedFlags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(or(A, B), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    AStart is SIn,
    AAccept is SIn + 1,
    BStart is SIn + 2,
    BAccept is SIn + 3,
    SIn1 is SIn + 4,
    ast_nfa(A, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut1),
    ast_nfa(B, Flags, BStart, BAccept, TransB, EpsB, SOut1, SOut),
    append(TransA, TransB, Trans),
    append(EpsA, EpsB, EpsSub),
    Eps = [eps(Start, AStart, always),
           eps(Start, BStart, always),
           eps(AAccept, Accept, always),
           eps(BAccept, Accept, always) | EpsSub].
ast_nfa(concat(A, B), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    flatten_concat(concat(A, B), Flat),
    factors_nfa(Flat, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(concat(List), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    list_si(List),
    !,
    flatten_list(List, Flat),
    factors_nfa(Flat, Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(postfix(Expr, star), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    AStart is SIn,
    AAccept is SIn + 1,
    SIn1 is SIn + 2,
    ast_nfa(Expr, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut),
    append(TransA, [], Trans),
    append(EpsA, [
        eps(Start, AStart, always),
        eps(Start, Accept, always),
        eps(AAccept, AStart, always),
        eps(AAccept, Accept, always)
    ], Eps).
ast_nfa(postfix(Expr, plus), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    AStart is SIn,
    AAccept is SIn + 1,
    SIn1 is SIn + 2,
    ast_nfa(Expr, Flags, AStart, AAccept, TransA, EpsA, SIn1, SOut),
    append(TransA, [], Trans),
    append(EpsA, [
        eps(Start, AStart, always),
        eps(AAccept, AStart, always),
        eps(AAccept, Accept, always)
    ], Eps).
ast_nfa(postfix(Expr, question), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
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
    !,
    ast_nfa(postfix(Expr, Op), Flags, Start, Accept, Trans, Eps, SIn, SOut).
ast_nfa(quant(Expr, Q), Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
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

expand_min_inf(Expr, 0, postfix(Expr, star)) :- !.
expand_min_inf(Expr, M, concat(Expr, Sub)) :-
    M > 0,
    M1 is M - 1,
    expand_min_inf(Expr, M1, Sub).

expand_min_max(_Expr, 0, 0, lit([])) :- !.
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
    !,
    flatten_concat(A, FlatA),
    flatten_concat(B, FlatB),
    append(FlatA, FlatB, Flat).
flatten_concat(concat(List), Flat) :-
    list_si(List),
    !,
    flatten_list(List, Flat).
flatten_concat(Expr, [Expr]).

flatten_list([], []).
flatten_list([H|T], Flat) :-
    flatten_concat(H, FlatH),
    flatten_list(T, FlatT),
    append(FlatH, FlatT, Flat).

% Threading factors with flags
factors_nfa([], _, Start, Accept, [], [eps(Start, Accept, always)], S, S).
factors_nfa([F], Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    !,
    ast_nfa(F, Flags, Start, Accept, Trans, Eps, SIn, SOut).
factors_nfa([F|Fs], Flags, Start, Accept, Trans, Eps, SIn, SOut) :-
    Fs = [_|_],
    !,
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

/* ---------- Copy of Helper Predicates from regexp_compile_dcg ---------- */

match_builtin(digit, C) :-
    C @>= '0', C @=< '9'.
match_builtin(not_digit, C) :-
    \+ (C @>= '0', C @=< '9').
match_builtin(word, C) :-
    (C @>= 'a', C @=< 'z') ; (C @>= 'A', C @=< 'Z') ; (C @>= '0', C @=< '9') ; C == '_'.
match_builtin(not_word, C) :-
    \+ match_builtin(word, C).
match_builtin(space, C) :-
    member(C, [' ', '\t', '\r', '\n']).
match_builtin(not_space, C) :-
    \+ match_builtin(space, C).

match_class(neg(List), C) :-
    !,
    \+ match_class_list(List, C).
match_class(List, C) :-
    list_si(List),
    match_class_list(List, C).

match_class_list([H|T], C) :-
    (   match_class_item(H, C) ->
        true
    ;   match_class_list(T, C)
    ).

match_class_item(char(C), C).
match_class_item(range(A, B), C) :-
    C @>= A, C @=< B.
match_class_item(builtin(Class), C) :-
    match_builtin(Class, C).

match_class_ci(neg(List), C) :-
    !,
    \+ match_class_list_ci(List, C).
match_class_ci(List, C) :-
    list_si(List),
    match_class_list_ci(List, C).

match_class_list_ci([H|T], C) :-
    (   match_class_item_ci(H, C) ->
        true
    ;   match_class_list_ci(T, C)
    ).

match_class_item_ci(char(CharPattern), C) :-
    char_equal_ci(CharPattern, C).
match_class_item_ci(range(A, B), C) :-
    char_lower(A, LowerA),
    char_lower(B, LowerB),
    char_lower(C, LowerC),
    LowerC @>= LowerA, LowerC @=< LowerB.
match_class_item_ci(builtin(Class), C) :-
    match_builtin(Class, C).

parse_flags(Flags, Parsed) :-
    to_chars(Flags, Chars),
    map_flags(Chars, Parsed).

map_flags([], []).
map_flags([C|Cs], [P|Ps]) :-
    map_flag_char(C, P),
    map_flags(Cs, Ps).

map_flag_char('i', case_insensitive).

char_lower(C, L) :-
    (   C @>= 'A', C @=< 'Z' ->
        char_code(C, Code),
        LowerCode is Code + 32,
        char_code(L, LowerCode)
    ;   L = C
    ).

char_equal_ci(C1, C2) :-
    char_lower(C1, L),
    char_lower(C2, L).

to_chars(Input, Input) :-
    list_si(Input),
    !.
to_chars(Input, Chars) :-
    atom_si(Input),
    !,
    atom_chars(Input, Chars).
to_chars(Input, _) :-
    domain_error(chars, Input).
