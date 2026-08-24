:- use_module(library(time)).
:- use_module(library(format)).
:- use_module(library(lists)).

:- use_module('../regexp_dcg').
:- use_module('../src/regexp_compile_dfa').
:- use_module('../regexp_tree').

% 20 C tokens and their corresponding regex patterns
c_tokens([
    % 1. Identifier
    token("my_variable_name", "[a-zA-Z_][a-zA-Z0-9_]*"),
    % 2. Decimal float
    token("123.456", "(?:[0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+)(?:[eE][+-]?[0-9]+)?[fFlL]?"),
    % 3. Decimal float with exponent
    token("1.2e-10", "(?:[0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+|[0-9]+)(?:[eE][+-]?[0-9]+)[fFlL]?"),
    % 4. Hex integer constant
    token("0xABC123", "0[xX][0-9a-fA-F]+[uUlL]*"),
    % 5. String literal
    token("\"hello, world!\"", "\\\"(?:[^\\\"\\\\]|\\\\.)*\\\""),
    % 6. Identifier
    token("printf", "[a-zA-Z_][a-zA-Z0-9_]*"),
    % 7. Left parenthesis
    token("(", "\\("),
    % 8. String literal with escape
    token("\"line 1\\nline 2\"", "\\\"(?:[^\\\"\\\\]|\\\\.)*\\\""),
    % 9. Right parenthesis
    token(")", "\\)"),
    % 10. Operator
    token("->", "->"),
    % 11. Operator
    token("++", "\\+\\+"),
    % 12. Identifier
    token("count", "[a-zA-Z_][a-zA-Z0-9_]*"),
    % 13. Semicolon
    token(";", ";"),
    % 14. Decimal integer constant
    token("42", "[0-9]+[uUlL]*"),
    % 15. Hex float constant
    token("0x1.5p-3", "0[xX](?:[0-9a-fA-F]+\\.[0-9a-fA-F]*|[0-9a-fA-F]*\\.[0-9a-fA-F]+|[0-9a-fA-F]+)(?:[pP][+-]?[0-9]+)[fFlL]?"),
    % 16. Empty string
    token("\"\"", "\\\"(?:[^\\\"\\\\]|\\\\.)*\\\""),
    % 17. Char literal
    token("'a'", "\\'(?:[^\\'\\\\]|\\\\.)*\\'"),
    % 18. Decimal Float starting with dot
    token(".5", "(?:[0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+)(?:[eE][+-]?[0-9]+)?[fFlL]?"),
    % 19. Operator
    token("==", "=="),
    % 20. Large decimal integer
    token("999999ULL", "[0-9]+[uUlL]*")
]).

% Run a goal N times
repeat_goal(0, _) :- !.
repeat_goal(N, Goal) :-
    call(Goal),
    N1 is N - 1,
    repeat_goal(N1, Goal).

% Match all 20 tokens using DCG (no cache)
dcg_nocache :-
    c_tokens(Tokens),
    regexp_dcg:re_clear_cache,
    match_all_dcg_nocache(Tokens).

match_all_dcg_nocache([]).
match_all_dcg_nocache([token(Input, Pattern)|Ts]) :-
    regexp_dcg:re_compile(Pattern, Compiled),
    regexp_dcg:re_match(Compiled, Input, _),
    match_all_dcg_nocache(Ts).

% Match all 20 tokens using DCG (with cache)
dcg_cached :-
    c_tokens(Tokens),
    match_all_dcg_cached(Tokens).

match_all_dcg_cached([]).
match_all_dcg_cached([token(Input, Pattern)|Ts]) :-
    regexp_dcg:re_match(Pattern, Input, _),
    match_all_dcg_cached(Ts).

% Match all 20 tokens using DFA (no cache)
dfa_nocache :-
    c_tokens(Tokens),
    regexp_dfa:re_clear_cache,
    match_all_dfa_nocache(Tokens).

match_all_dfa_nocache([]).
match_all_dfa_nocache([token(Input, Pattern)|Ts]) :-
    regexp_dfa:re_compile(Pattern, NFA),
    regexp_dfa:re_match(NFA, Input, _),
    match_all_dfa_nocache(Ts).

% Match all 20 tokens using DFA (with cache)
dfa_cached :-
    c_tokens(Tokens),
    match_all_dfa_cached(Tokens).

match_all_dfa_cached([]).
match_all_dfa_cached([token(Input, Pattern)|Ts]) :-
    regexp_dfa:re_match(Pattern, Input, _),
    match_all_dfa_cached(Ts).

% Match all 20 tokens using Rational Tree Automata (no cache)
tree_nocache :-
    c_tokens(Tokens),
    regexp_tree:re_tree_clear_cache,
    match_all_tree_nocache(Tokens).

match_all_tree_nocache([]).
match_all_tree_nocache([token(Input, Pattern)|Ts]) :-
    regexp_tree:re_tree_compile(Pattern, Compiled),
    regexp_tree:re_tree_match(Compiled, Input, _),
    match_all_tree_nocache(Ts).

% Match all 20 tokens using Rational Tree Automata (with cache)
tree_cached :-
    c_tokens(Tokens),
    match_all_tree_cached(Tokens).

match_all_tree_cached([]).
match_all_tree_cached([token(Input, Pattern)|Ts]) :-
    regexp_tree:re_tree_match(Pattern, Input, _),
    match_all_tree_cached(Ts).

% Match all 20 tokens using pre-compiled objects (pure match engine comparison)
precompiled_dcg(Precompiled) :-
    c_tokens(Tokens),
    match_precompiled_dcg(Tokens, Precompiled).

match_precompiled_dcg([], []).
match_precompiled_dcg([token(Input, _)|Ts], [Goal|Gs]) :-
    regexp_dcg:re_match(Goal, Input, _),
    match_precompiled_dcg(Ts, Gs).

precompiled_dfa(Precompiled) :-
    c_tokens(Tokens),
    match_precompiled_dfa(Tokens, Precompiled).

match_precompiled_dfa([], []).
match_precompiled_dfa([token(Input, _)|Ts], [NFA|Ns]) :-
    regexp_dfa:re_match(NFA, Input, _),
    match_precompiled_dfa(Ts, Ns).

precompiled_tree(Precompiled) :-
    c_tokens(Tokens),
    match_precompiled_tree(Tokens, Precompiled).

match_precompiled_tree([], []).
match_precompiled_tree([token(Input, _)|Ts], [Compiled|Cs]) :-
    regexp_tree:re_tree_match(Compiled, Input, _),
    match_precompiled_tree(Ts, Cs).

% Compile C patterns to structures once
compile_all_dcg([], []).
compile_all_dcg([token(_, Pattern)|Ts], [Goal|Gs]) :-
    regexp_dcg:re_compile(Pattern, Goal),
    compile_all_dcg(Ts, Gs).

compile_all_dfa([], []).
compile_all_dfa([token(_, Pattern)|Ts], [NFA|Ns]) :-
    regexp_dfa:re_compile(Pattern, NFA),
    compile_all_dfa(Ts, Ns).

compile_all_tree([], []).
compile_all_tree([token(_, Pattern)|Ts], [Compiled|Cs]) :-
    regexp_tree:re_tree_compile(Pattern, Compiled),
    compile_all_tree(Ts, Cs).

main :-
    c_tokens(Tokens),
    format("==============================================================~n", []),
    format("Regex Performance Benchmark: DCG vs DFA vs Rational Tree Automaton~n", []),
    format("Number of C tokens matched sequentially: ~d~n", [20]),
    format("==============================================================~n~n", []),

    % Warm up caches
    format("Warming up caches...~n", []),
    dcg_cached,
    dfa_cached,
    tree_cached,
    compile_all_dcg(Tokens, PrecompiledDCG),
    compile_all_dfa(Tokens, PrecompiledDFA),
    compile_all_tree(Tokens, PrecompiledTree),
    format("Warm up complete.~n~n", []),

    Iterations = 100,
    format("--- Iterations per test: ~d ---~n~n", [Iterations]),

    format("1. [DCG / Backtracking] Match with compilation on the fly (no cache):~n", []),
    time(repeat_goal(Iterations, dcg_nocache)),
    format("~n", []),

    format("2. [DFA] Match with NFA compilation on the fly (no cache):~n", []),
    time(repeat_goal(Iterations, dfa_nocache)),
    format("~n", []),

    format("3. [Rational Tree] Match with Tree compilation on the fly (no cache):~n", []),
    time(repeat_goal(Iterations, tree_nocache)),
    format("~n", []),

    format("4. [DCG / Backtracking] Match using dynamic compilation cache:~n", []),
    time(repeat_goal(Iterations, dcg_cached)),
    format("~n", []),

    format("5. [DFA] Match using dynamic compilation cache:~n", []),
    time(repeat_goal(Iterations, dfa_cached)),
    format("~n", []),

    format("6. [Rational Tree] Match using dynamic compilation cache:~n", []),
    time(repeat_goal(Iterations, tree_cached)),
    format("~n", []),

    format("7. [DCG / Backtracking] Pure match engine (pre-compiled goals):~n", []),
    time(repeat_goal(Iterations, precompiled_dcg(PrecompiledDCG))),
    format("~n", []),

    format("8. [DFA] Pure match engine (pre-compiled NFAs):~n", []),
    time(repeat_goal(Iterations, precompiled_dfa(PrecompiledDFA))),
    format("~n", []),

    format("9. [Rational Tree] Pure match engine (pre-compiled trees):~n", []),
    time(repeat_goal(Iterations, precompiled_tree(PrecompiledTree))),
    format("~n", []),

    halt.
