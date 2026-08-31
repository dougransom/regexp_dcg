/**
  Provides rational tree automaton compilation and pure if_/3 matching for regular expressions.

  This module compiles AST terms into rational tree automaton nodes represented as
  `sym(Condition, SuccState, FailState)`, `alt(NodeA, NodeB)`, `star(SubNode, Cont)`, `opt(SubNode, Cont)`,
  `end`, `stp`, and capture nodes.

  Based on the Scryer Prolog rational tree automaton matching model:
  https://github.com/mthom/scryer-prolog/discussions/2758

  ### Matching Paradigms

  1. **Rational Tree Automaton Execution (`regex_tree_run/5`)**:
     Evaluates compiled automaton nodes using pure `if_/3` character condition tests:
     ```prolog
     ?- compile_ast_tree(AST, Automaton, Groups),
        regex_tree_run(Automaton, Input, Rest, State0, StateF).
     ```

  2. **Pre-Compiling AST to Tree Automata (`compile_ast_tree/3`)**:
     Translates regular expression AST structures into cyclic tree automaton nodes.

  ### Supported Regular Expression Syntax

  | Feature Category | Syntax | Description |
  |---|---|---|
  | **Literals** | `abc` | Match literal characters exactly. Escaped metacharacters (e.g. `\*`) match the metacharacter itself. |
  | **Wildcard** | `.` | Match any single character (except newline unless inline flag `s` is set). |
  | **Alternation** | `A\|B` | Match either sub-expression `A` or `B`. |
  | **Anchors** | `^` / `$` | Match the beginning or end of the input string. |
  | **Word Boundaries**| `\b` / `\B` | Match a word boundary or a non-word boundary. |
  | **Builtin Classes**| `\d` / `\D` | Match a digit `[0-9]` or not a digit `[^0-9]`. |
  | | `\w` / `\W` | Match a word character `[a-zA-Z0-9_]` or not a word character. |
  | | `\s` / `\S` | Match a whitespace character (space, tab, newline, carriage return, form feed, vertical tab) or not a whitespace. |
  | **Custom Classes** | `[abc]` / `[^abc]` | Match any character in the class (or not in the class if negated with `^`). |
  | | `[a-z]` / `[^a-z]` | Range matching inside character classes. |
  | | `[:digit:]` / `[:alpha:]` | POSIX character classes inside brackets (e.g. `[:alnum:]`, `[:space:]`). |
  | **Quantifiers** | `*` / `*?` | Greedy or lazy Kleene star (0 or more repetitions). |
  | | `+` / `+?` | Greedy or lazy Kleene plus (1 or more repetitions). |
  | | `?` / `??` | Greedy or lazy optional (0 or 1 repetition). |
  | | `{n}` / `{n}?` | Repetition exactly `n` times. |
  | | `{n,}` / `{n,}?` | Open-ended repetition: at least `n` times. |
  | | `{n,m}` / `{n,m}?`| Bounded repetition: between `n` and `m` times. |
  | **Groups & Captures**| `(...)` | Capturing group (extracts substring into numbered capture list). |
  | | `(?:...)` | Non-capturing group. |
  | | `(?P<name>...)` | Named capturing group. |
  | **Assertions** | `(?=...)` | Positive lookahead assertion. |
  | | `(?!...)` | Negative lookahead assertion. |
  | **Flags** | `(?flags)` | Inline flags setting: `i` (case-insensitive), `m` (multi-line), `s` (dot-all), `x` (verbose), etc. |
  | | `(?flags:...)` | Flags applied locally to a sub-expression group. |

  ### Multilingual & International Character Support

  In ISO Prolog systems treating `double_quotes` as character lists (`chars`), strings represent sequences of native character code points.
  Exact literal matching, wildcards (`.`), custom character classes (`[α-ω]`), capturing groups, Emojis, and non-Latin scripts (e.g. Greek, CJK, Klingon script PUA) work out of the box.

  > [!NOTE]
  > **Case-Insensitivity Limitation (`(?i)`)**: Inline flag `(?i)` case folding is currently scoped to ASCII characters (`'A'-'Z'` $\leftrightarrow$ `'a'-'z'`). Non-ASCII international uppercase/lowercase foldings (e.g. `'É'` $\leftrightarrow$ `'é'`) are not automatically folded by `(?i)`.
*/
:- module(regexp_compile_tree, [
    compile_ast_tree/3,
    get_tree_automaton/3,
    regex_tree_run//3,
    match_cond/3,
    match_cond_empty/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(reif)).
:- use_module(library(si)).
:- use_module(library(dif)).
:- use_module(library(clpz)).
:- use_module(library(error)).
:- use_module(regexp_common, [
    match_builtin_t/3,
    char_range_t/4,
    parse_flags/2,
    char_lower/2,
    char_equal_ci/2,
    char_equal_ci_t/3,
    to_chars/2,
    match_class_t/3,
    match_class_ci_t/3,
    pattern_ast/2,
    is_input_arg_t/2,
    pattern_cache_t/5,
    pattern_cache_put/4,
    clear_pattern_cache/1,
    pattern_cache_info/3,
    get_or_compile_pattern/5
]).

/**
  ### Multi-Tier Pattern Cache for Tree Automata

  `get_tree_automaton/3` resolves an input `Pattern` (either a pre-compiled `compiled_tree/2` term,
  a cached pattern string, or a raw string/atom) into an `Automaton` term graph and `GroupCount`.
*/

%% get_tree_automaton(+Pattern, -Automaton, -GroupCount)
get_tree_automaton(Pattern, Automaton, GroupCount) :-
    if_(var_t(Pattern),
        instantiation_error(get_tree_automaton/3),
        if_(compiled_tree_t(Pattern),
            Pattern = compiled_tree(Automaton, GroupCount),
            get_string_tree_automaton(Pattern, Automaton, GroupCount)
        )
    ).

%% compiled_tree_t(+Pattern, -Truth)
%
% Reified test for whether `Pattern` is a pre-compiled `compiled_tree(Automaton, GroupCount)` term.
%
% Reification Explanation:
% Designed specifically for `library(reif)`'s `if_/3` conditional. Binds `Truth` to `true` if `Pattern`
% unifies with `compiled_tree(_, _)`, or `false` if `Pattern` is any other term.
compiled_tree_t(compiled_tree(_, _), true).
compiled_tree_t(Pattern, false) :-
    Pattern \= compiled_tree(_, _).

%% var_t(+Term, -Truth)
%
% Reified test for term instantiation (`var` vs `nonvar`).
%
% Reification Explanation:
% Designed specifically for `library(reif)`'s `if_/3` conditional. Binds `Truth` to `true` if `Term` is unbound,
% or `false` if `Term` is instantiated.
var_t(X, true) :- var(X).
var_t(X, false) :- nonvar(X).

get_string_tree_automaton(Pattern, Automaton, GroupCount) :-
    get_or_compile_pattern(tree, Pattern, regexp_compile_tree:compile_ast_tree, Automaton, GroupCount).

%% compile_ast_tree(+AST, -Automaton, -GroupCount)
%
% Compiles regex AST into a tree automaton `Automaton` and counts captured groups.
compile_ast_tree(AST, Automaton, GroupCount) :-
    compile_node(AST, 0, GroupCount, end, Automaton).

%% compile_node(+AST, +C0, -CF, +Cont, -Node)
%
% Compiles an AST node into an automaton node with continuation `Cont`.
compile_node(lit([]), C, C, Cont, Cont).
compile_node(lit([Char]), C, C, Cont, sym(char(Char), Cont, stp)).
compile_node(lit([C1, C2 | Cs]), C, C, Cont, Node) :-
    compile_node(lit([C2 | Cs]), C, C, Cont, RestNode),
    Node = sym(char(C1), RestNode, stp).

compile_node(concat(A, B), C0, CF, Cont, Node) :-
    compile_node(A, C0, C1, NodeB, Node),
    compile_node(B, C1, CF, Cont, NodeB).
compile_node(concat(List), C0, CF, Cont, Node) :-
    compile_seq(List, C0, CF, Cont, Node).

compile_node(or(A, B), C0, CF, Cont, alt(NodeA, NodeB)) :-
    compile_node(A, C0, C1, Cont, NodeA),
    compile_node(B, C1, CF, Cont, NodeB).

compile_node(group(Inner), C0, CF, Cont, Node) :-
    compile_node(Inner, C0, CF, Cont, Node).

compile_node(capture(Inner), C0, CF, Cont, cap_open(C0, NodeInner)) :-
    C1 #= C0 + 1,
    compile_node(Inner, C1, CF, cap_close(C0, Cont), NodeInner).

compile_node(named_capture(Name, Inner), C0, CF, Cont, named_open(Name, C0, NodeInner)) :-
    C1 #= C0 + 1,
    compile_node(Inner, C1, CF, named_close(Name, C0, Cont), NodeInner).

compile_node(postfix(Expr, star), C0, CF, Cont, star(SubNode, Cont)) :-
    compile_node(Expr, C0, CF, end, SubNode).

compile_node(postfix(Expr, lazy(star)), C0, CF, Cont, lazy_star(SubNode, Cont)) :-
    compile_node(Expr, C0, CF, end, SubNode).

compile_node(postfix(Expr, plus), C0, CF, Cont, Node) :-
    compile_node(Expr, C0, C1, star(SubNode, Cont), Node),
    compile_node(Expr, C1, CF, end, SubNode).

compile_node(postfix(Expr, lazy(plus)), C0, CF, Cont, Node) :-
    compile_node(Expr, C0, C1, lazy_star(SubNode, Cont), Node),
    compile_node(Expr, C1, CF, end, SubNode).

compile_node(postfix(Expr, question), C0, CF, Cont, opt(SubNode, Cont)) :-
    compile_node(Expr, C0, CF, Cont, SubNode).

compile_node(postfix(Expr, lazy(question)), C0, CF, Cont, lazy_opt(SubNode, Cont)) :-
    compile_node(Expr, C0, CF, Cont, SubNode).

compile_node(quant(Expr, mn(M, M)), C0, CF, Cont, Node) :-
    compile_exact_n(M, Expr, C0, CF, Cont, Node).
compile_node(quant(Expr, mn(0, inf)), C0, CF, Cont, Node) :-
    compile_node(postfix(Expr, star), C0, CF, Cont, Node).
compile_node(quant(Expr, mn(M, inf)), C0, CF, Cont, Node) :-
    M #> 0,
    compile_node(postfix(Expr, star), C0, C1, Cont, NodeStar),
    compile_exact_n(M, Expr, C1, CF, NodeStar, Node).
compile_node(quant(Expr, mn(M, N)), C0, CF, Cont, Node) :-
    M #=< N,
    dif(N, inf),
    RestCount #= N - M,
    compile_optionals(RestCount, Expr, C0, C1, Cont, NodeOpt),
    compile_exact_n(M, Expr, C1, CF, NodeOpt, Node).

compile_node(quant(Expr, lazy(mn(M, M))), C0, CF, Cont, Node) :-
    compile_exact_n(M, Expr, C0, CF, Cont, Node).
compile_node(quant(Expr, lazy(mn(0, inf))), C0, CF, Cont, Node) :-
    compile_node(postfix(Expr, lazy(star)), C0, CF, Cont, Node).
compile_node(quant(Expr, lazy(mn(M, inf))), C0, CF, Cont, Node) :-
    M #> 0,
    compile_node(postfix(Expr, lazy(star)), C0, C1, Cont, NodeStar),
    compile_exact_n(M, Expr, C1, CF, NodeStar, Node).
compile_node(quant(Expr, lazy(mn(M, N))), C0, CF, Cont, Node) :-
    M #=< N,
    dif(N, inf),
    RestCount #= N - M,
    compile_lazy_optionals(RestCount, Expr, C0, C1, Cont, NodeOpt),
    compile_exact_n(M, Expr, C1, CF, NodeOpt, Node).

compile_node(dot, C, C, Cont, sym(dot, Cont, stp)).
compile_node(escaped(Char), C, C, Cont, Node) :-
    if_(char_range_t('1', '9', Char),
        ( char_code(Char, Code), Idx #= Code - 49, Node = backref(Idx, Cont) ),
        Node = sym(char(Char), Cont, stp)).

compile_node(anchor(bol), C, C, Cont, sym(bol, Cont, stp)).
compile_node(anchor(eol), C, C, Cont, sym(eol, Cont, stp)).
compile_node(boundary, C, C, Cont, sym(boundary, Cont, stp)).
compile_node(boundary(word), C, C, Cont, sym(boundary, Cont, stp)).
compile_node(not_boundary, C, C, Cont, sym(not_boundary, Cont, stp)).
compile_node(boundary(not_word), C, C, Cont, sym(not_boundary, Cont, stp)).
compile_node(backref(Idx), C, C, Cont, backref(Idx, Cont)).
compile_node(builtin(Class), C, C, Cont, sym(builtin(Class), Cont, stp)).
compile_node(class(neg(Items)), C, C, Cont, sym(neg_class(Items), Cont, stp)).
compile_node(class(Items), C, C, Cont, sym(class(Items), Cont, stp)).
compile_node(neg_class(Items), C, C, Cont, sym(neg_class(Items), Cont, stp)).
compile_node(lookahead(Sub), C0, CF, Cont, lookahead(SubNode, Cont, stp)) :-
    compile_node(Sub, C0, CF, end, SubNode).
compile_node(neg_lookahead(Sub), C0, CF, Cont, neg_lookahead(SubNode, Cont, stp)) :-
    compile_node(Sub, C0, CF, end, SubNode).
compile_node(flags(Flags), C, C, Cont, set_flags(Flags, Cont)).
compile_node(flags(Flags, Sub), C0, CF, Cont, scoped_flags(Flags, SubNode, Cont)) :-
    compile_node(Sub, C0, CF, Cont, SubNode).

compile_seq([], C, C, Cont, Cont).
compile_seq([H|T], C0, CF, Cont, Node) :-
    compile_node(H, C0, C1, RestNode, Node),
    compile_seq(T, C1, CF, Cont, RestNode).

compile_exact_n(0, _, C, C, Cont, Cont).
compile_exact_n(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_exact_n(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(Expr, C1, CF, RestNode, Node).

compile_optionals(0, _, C, C, Cont, Cont).
compile_optionals(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_optionals(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(postfix(Expr, question), C1, CF, RestNode, Node).

compile_lazy_optionals(0, _, C, C, Cont, Cont).
compile_lazy_optionals(N, Expr, C0, CF, Cont, Node) :-
    N #> 0,
    N1 #= N - 1,
    compile_lazy_optionals(N1, Expr, C0, C1, Cont, RestNode),
    compile_node(postfix(Expr, lazy(question)), C1, CF, RestNode, Node).

%% regex_tree_run(+Automaton, +S0, -SF)//
%
% Runs the rational tree automaton `Automaton` on the input character stream.
% Character difference-list threading (Chars -> Rest) is managed implicitly via DCGs.
%
% State Threading (S0 -> SF):
%   S0 is the initial engine execution state before evaluating an automaton node,
%   and SF is the final engine execution state after evaluating the node.
%
%   Both S0 and SF are compound terms structured as:
%     state(Full, Groups, Named, Flags)
%
%   - Full: The full input character sequence passed at the start of matching.
%           Serves as an immutable reference for computing capture slice lengths.
%   - Groups: Positional capture groups list ([Group0, Group1, ...]), initialized
%             as unbound variables [_, _, ...] of length GroupCount.
%   - Named: Named capture groups key-value pair list ([name1-Substr1, ...]).
%   - Flags: Active execution flags list (e.g. [case_insensitive]) set by inline flags.
regex_tree_run(end, State, State) --> [].

regex_tree_run(stp, _, _) --> { fail }.

regex_tree_run(alt(NodeA, NodeB), S0, SF) -->
    (   regex_tree_run(NodeA, S0, SF)
    ;   regex_tree_run(NodeB, S0, SF)
    ).

regex_tree_run(star(SubNode, Cont), S0, SF) -->
    (   regex_tree_run_star(SubNode, Cont, S0, SF)
    ;   regex_tree_run(Cont, S0, SF)
    ).

regex_tree_run(lazy_star(SubNode, Cont), S0, SF) -->
    (   regex_tree_run(Cont, S0, SF)
    ;   regex_tree_run_star(SubNode, Cont, S0, SF)
    ).

regex_tree_run(opt(SubNode, Cont), S0, SF) -->
    (   regex_tree_run(SubNode, S0, SF)
    ;   regex_tree_run(Cont, S0, SF)
    ).

regex_tree_run(lazy_opt(SubNode, Cont), S0, SF) -->
    (   regex_tree_run(Cont, S0, SF)
    ;   regex_tree_run(SubNode, S0, SF)
    ).

regex_tree_run(cap_open(Idx, Next), S0, SF) -->
    state_remaining(Chars),
    { update_cap_open(S0, Idx, Chars, S1) },
    regex_tree_run(Next, S1, SF).

regex_tree_run(cap_close(Idx, Next), S0, SF) -->
    state_remaining(Chars),
    { update_cap_close(S0, Idx, Chars, S1) },
    regex_tree_run(Next, S1, SF).

regex_tree_run(named_open(Name, Idx, Next), S0, SF) -->
    state_remaining(Chars),
    { update_named_open(S0, Name, Idx, Chars, S1) },
    regex_tree_run(Next, S1, SF).

regex_tree_run(named_close(Name, Idx, Next), S0, SF) -->
    state_remaining(Chars),
    { update_named_close(S0, Name, Idx, Chars, S1) },
    regex_tree_run(Next, S1, SF).

% Note on ->: Soft-cut is used for lookahead assertions because SubNode execution
% is a recursive goal search (not a reified boolean value for if_/3). Soft-cut commits
% to the first successful match of the zero-width lookahead assertion.
regex_tree_run(lookahead(SubNode, Next, Fail), S0, SF) -->
    state_remaining(Chars),
    { (   phrase(regex_tree_run(SubNode, S0, _), Chars, _) ->
          NextNode = Next
      ;   NextNode = Fail
      )
    },
    regex_tree_run(NextNode, S0, SF).

regex_tree_run(neg_lookahead(SubNode, Next, Fail), S0, SF) -->
    state_remaining(Chars),
    { (   phrase(regex_tree_run(SubNode, S0, _), Chars, _) ->
          NextNode = Fail
      ;   NextNode = Next
      )
    },
    regex_tree_run(NextNode, S0, SF).

regex_tree_run(set_flags(Flags, Next), S0, SF) -->
    { S0 = state(Full, Groups, Named, OldFlags),
      parse_flags(Flags, NewFlags),
      append(NewFlags, OldFlags, CombinedFlags),
      S1 = state(Full, Groups, Named, CombinedFlags)
    },
    regex_tree_run(Next, S1, SF).

regex_tree_run(scoped_flags(Flags, SubNode, Next), S0, SF) -->
    { S0 = state(Full, Groups, Named, OldFlags),
      parse_flags(Flags, NewFlags),
      append(NewFlags, OldFlags, CombinedFlags),
      S1 = state(Full, Groups, Named, CombinedFlags)
    },
    state_remaining(Chars),
    { phrase(regex_tree_run(SubNode, S1, S2), Chars, Rest1) },
    set_remaining(Rest1),
    { S2 = state(Full2, Groups2, Named2, _),
      SFinal = state(Full2, Groups2, Named2, OldFlags)
    },
    regex_tree_run(Next, SFinal, SF).

regex_tree_run(backref(Idx, Next), S0, SF) -->
    { S0 = state(_, Groups, _, _) },
    state_remaining(Chars),
    { backref_matched_t(Idx, Groups, Chars, RestChars, Truth) },
    (   { Truth == true } ->
        set_remaining(RestChars),
        regex_tree_run(Next, S0, SF)
    ;   { fail }
    ).

regex_tree_run(sym(Cond, Succ, Fail), S0, SF) -->
    { is_zero_width_cond(Cond) },
    !,
    state_remaining(Chars),
    { if_(match_cond_zero_t(Cond, S0, Chars),
          NextNode = Succ,
          NextNode = Fail) },
    regex_tree_run(NextNode, S0, SF).

% Non-empty input matching using if_/3 reified condition
regex_tree_run(sym(Cond, Succ, Fail), S0, SF) -->
    state_remaining(Chars),
    { if_(Chars = [],
          ( if_(match_cond_empty(Cond), NextNode = Succ, NextNode = Fail), RestChars = [] ),
          ( Chars = [H|T],
            S0 = state(_, _, _, Flags),
            if_(match_cond_flags(Cond, H, Flags),
                ( NextNode = Succ, RestChars = T ),
                ( NextNode = Fail, RestChars = Chars )
            )
          )
      )
    },
    set_remaining(RestChars),
    regex_tree_run(NextNode, S0, SF).

regex_tree_run_star(SubNode, Cont, S0, SF) -->
    state_remaining(Chars),
    regex_tree_run(SubNode, S0, S1),
    state_remaining(Rest1),
    { dif(Rest1, Chars) },
    regex_tree_run(star(SubNode, Cont), S1, SF).

%% state_remaining(-Chars)//
% Accesses current DCG input character stream without consuming.
state_remaining(Chars, Chars, Chars).

%% set_remaining(+Rest)//
% Updates DCG input character stream to Rest.
set_remaining(Rest, _OldChars, Rest).

backref_matched_t(Idx, Groups, Chars, RestChars, true) :-
    nth0(Idx, Groups, Captured),
    chars_si(Captured),
    append(Captured, RestChars, Chars), !.
backref_matched_t(_Idx, _Groups, _Chars, _RestChars, false).

is_zero_width_cond(bol).
is_zero_width_cond(eol).
is_zero_width_cond(boundary).
is_zero_width_cond(not_boundary).

match_cond_zero_t(bol, S0, Chars, Truth) :-
    is_bol_t(S0, Chars, Truth).
match_cond_zero_t(eol, _S0, Chars, Truth) :-
    is_eol_t(Chars, Truth).
match_cond_zero_t(boundary, S0, Chars, Truth) :-
    is_boundary_t(S0, Chars, Truth).
match_cond_zero_t(not_boundary, S0, Chars, Truth) :-
    is_boundary_t(S0, Chars, T0),
    if_(T0 = true, Truth = false, Truth = true).

%% match_cond_empty(+Cond, -Truth)
match_cond_empty(Cond, Truth) :-
    if_(Cond = eol, Truth = true, Truth = false).

%% match_cond_flags(+Cond, +Char, +Flags, -Truth)
match_cond_flags(Cond, H, Flags, Truth) :-
    if_(memberd_t(case_insensitive, Flags),
        match_cond_ci(Cond, H, Truth),
        match_cond(Cond, H, Truth)).

%% match_cond(+Cond, +Char, -Truth)
match_cond(char(C), H, Truth) :-
    =(C, H, Truth).

match_cond(dot, H, Truth) :-
    if_(H = '\n', Truth = false, Truth = true).

match_cond(bol, _H, true).
match_cond(eol, _H, false).
match_cond(boundary, _H, true).
match_cond(not_boundary, _H, true).

match_cond(builtin(Code), H, Truth) :-
    match_builtin_t(Code, H, Truth).

match_cond(class(Items), H, Truth) :-
    match_class_t(Items, H, Truth).

match_cond(neg_class(Items), H, Truth) :-
    match_class_t(neg(Items), H, Truth).

%% match_cond_ci(+Cond, +Char, -Truth)
match_cond_ci(char(C), H, Truth) :-
    char_equal_ci_t(C, H, Truth).
match_cond_ci(class(Items), H, Truth) :-
    match_class_ci_t(Items, H, Truth).
match_cond_ci(neg_class(Items), H, Truth) :-
    match_class_ci_t(neg(Items), H, Truth).
match_cond_ci(Cond, H, Truth) :-
    match_cond(Cond, H, Truth).

/* Helper state modifiers for group capture tracking */

update_cap_open(state(Full, Groups, Named, Flags), Idx, RemainingChars, state(Full, NewGroups, Named, Flags)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups).

update_cap_close(state(Full, Groups, Named, Flags), Idx, RemainingChars, state(Full, NewGroups, Named, Flags)) :-
    set_group_end(Full, Groups, Idx, RemainingChars, NewGroups).

update_named_open(state(Full, Groups, Named, Flags), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed, Flags)) :-
    set_group_start(Groups, Idx, RemainingChars, NewGroups),
    set_named_start(Named, Name, Idx, RemainingChars, NewNamed).

update_named_close(state(Full, Groups, Named, Flags), Name, Idx, RemainingChars, state(Full, NewGroups, NewNamed, Flags)) :-
    set_group_end(Full, Groups, Idx, RemainingChars, NewGroups),
    set_named_end(Full, Named, Name, Idx, RemainingChars, NewNamed).

set_group_start(Groups, Idx, RemainingChars, NewGroups) :-
    if_(group_captured_t(Groups, Idx, RemainingChars),
        NewGroups = Groups,
        replace_nth(Groups, Idx, capture(RemainingChars, _), NewGroups)
    ).

group_captured_t(Groups, Idx, RemainingChars, true) :-
    nth0(Idx, Groups, capture(CapChars, _)),
    CapChars == RemainingChars, !.
group_captured_t(_Groups, _Idx, _RemainingChars, false).

set_group_end(Full, Groups, Idx, RemainingChars, NewGroups) :-
    if_(group_start_captured_t(Groups, Idx, StartChars),
        ( extract_substring(Full, StartChars, RemainingChars, Substr),
          replace_nth(Groups, Idx, Substr, NewGroups) ),
        NewGroups = Groups
    ).

group_start_captured_t(Groups, Idx, StartChars, true) :-
    nth0(Idx, Groups, capture(StartChars, _)), !.
group_start_captured_t(_Groups, _Idx, _StartChars, false).

set_named_start(Named, Name, _, RemainingChars, [Name-capture(RemainingChars, _)|Named1]) :-
    delete_key(Named, Name, Named1).

set_named_end(Full, Named, Name, _, RemainingChars, [Name-Substr|Named1]) :-
    if_(named_captured_t(Named, Name, StartChars),
        ( extract_substring(Full, StartChars, RemainingChars, Substr),
          delete_key(Named, Name, Named1) ),
        Named1 = Named
    ).

named_captured_t(Named, Name, StartChars, true) :-
    member(Name-capture(StartChars, _), Named), !.
named_captured_t(_Named, _Name, _StartChars, false).

delete_key([], _, []).
delete_key([K0-V|T], K, R) :-
    if_(K0 = K,
        delete_key(T, K, R),
        ( R = [K0-V|R1], delete_key(T, K, R1) )).

replace_nth(List, N, Val, NewList) :-
    list_split_at(N, List, Prefix, [_|Suffix]),
    append(Prefix, [Val|Suffix], NewList).

extract_substring(Full, StartChars, EndChars, Substr) :-
    length(Full, LFull),
    length(StartChars, LStart),
    length(EndChars, LEnd),
    Skip #= LFull - LStart,
    Take #= LStart - LEnd,
    drop_n(Skip, Full, Rest),
    take_n(Take, Rest, Substr).

list_split_at(N, List, Prefix, Suffix) :-
    length(Prefix, N),
    append(Prefix, Suffix, List).

drop_n(N, List, Drop) :-
    list_split_at(N, List, _, Drop).

take_n(N, List, Take) :-
    list_split_at(N, List, Take, _).

is_bol_t(state(Full, _, _, _), Chars, Truth) :-
    if_(Full = Chars,
        Truth = true,
        ( length(Full, LFull),
          length(Chars, LChars),
          Skip #= LFull - LChars - 1,
          Skip #>= 0 #<==> B,
          if_(B = 1,
              ( nth0(Skip, Full, NL), if_(NL = '\n', Truth = true, Truth = false) ),
              Truth = false)
        )).

is_eol_t(Chars, Truth) :-
    if_(Chars = [],
        Truth = true,
        if_(Chars = ['\n'|_], Truth = true, Truth = false)).

is_boundary_t(state(Full, _, _, _), Chars, Truth) :-
    if_(Full = Chars,
        ( Chars = [H|_], is_word_char_t(H, Truth) ),
        if_(Chars = [],
            ( length(Full, LFull),
              Skip #= LFull - 1,
              Skip #>= 0 #<==> B,
              if_(B = 1,
                  ( nth0(Skip, Full, Prev), is_word_char_t(Prev, Truth) ),
                  Truth = false)
            ),
            ( length(Full, LFull),
              length(Chars, LChars),
              Skip #= LFull - LChars - 1,
              Skip #>= 0 #<==> B,
              if_(B = 1,
                  ( nth0(Skip, Full, Prev),
                    Chars = [Curr|_],
                    is_word_char_t(Prev, T1),
                    is_word_char_t(Curr, T2),
                    if_(T1 = T2, Truth = false, Truth = true)
                  ),
                  Truth = false)
            ))).

is_bol(State, Chars) :- is_bol_t(State, Chars, true).
is_eol(Chars) :- is_eol_t(Chars, true).
is_boundary(State, Chars) :- is_boundary_t(State, Chars, true).

is_word_char(C) :-
    is_word_char_t(C, true).

is_word_char_t(C, Truth) :-
    if_(var_t(C),
        Truth = false,
        match_builtin_t(word, C, Truth)
    ).
