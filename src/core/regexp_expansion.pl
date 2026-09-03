/**
  Provides compile-time macro expansion (goal_expansion and term_expansion)
  for regular expressions in Scryer Prolog.

  ### Expansion Approaches:
  - **Approach A (Default, `user:regexp_expansion(term)`):**
    Compile-time precompiled automaton inlining via `user:goal_expansion/2`.
    When `re_match/2-3`, `re_match_groups/4-5`, or `re_match_named/4-5` is called with a literal pattern
    (character list `"..."` or atom `'...'`), the pattern is compiled at load time into the target
    engine's precompiled automaton structure and inlined directly into the clause.
    **Patterns compiled from literals bypass the dynamic pattern cache entirely.**
  - **Approach B (`user:regexp_expansion(rules)` or `re_rule//0`):**
    Direct Prolog DCG rule and clause generation via `user:term_expansion/2`.
    Enables declarative definition of named DCG grammar non-terminals directly from regex patterns:
    `re_rule(name//0, "pattern")` or `re_rule(name(Match)//0, "pattern")`.

  ### Engine & Mode Selection:
  - **Engine Mode:** Configured via `user:regexp_engine(Engine)` or `user:regexp_mode(Engine)`
    with values `tree` (default), `dcg`, or `dfa`.
  - **Expansion Mode:** Configured via `user:regexp_expansion(Mode)` with values `term` (default)
    or `rules`.
*/
:- module(regexp_expansion, [
    current_regexp_engine/1,
    current_static_engine/1,
    current_dynamic_engine/1,
    static_compilation_enabled/0,
    normalize_engine/2,
    current_regexp_expansion/1,
    compile_literal_pattern/3,
    is_literal_pattern/2,
    expand_literal_goal/2
]).

:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(si)).
:- use_module(library(error)).
:- use_module(library(reif)).

:- use_module(regexp_common, [
    to_chars/2,
    pattern_ast/2
]).
:- use_module(regexp_compile_tree, [compile_ast_tree/3]).
:- use_module(regexp_compile_dcg, [ast_dcg_goal/4]).
:- use_module(regexp_compile_dfa, [compile_ast_dfa/3]).

:- multifile(user:goal_expansion/2).
:- multifile(user:term_expansion/2).

%% normalize_engine(@Raw, -Normalized)
%
% Normalizes user-specified engine names and aliases:
%   - rt, tree, rational_tree -> tree
%   - dcg, backtracking      -> dcg
%   - dfa                    -> dfa
normalize_engine(Raw, Normalized) :-
    if_((Raw = tree ; Raw = rt ; Raw = rational_tree),
        Normalized = tree,
        if_((Raw = dcg ; Raw = backtracking),
            Normalized = dcg,
            if_(Raw = dfa,
                Normalized = dfa,
                domain_error(regexp_engine, Raw)))).

%% current_global_engine(-Engine)
%
% Determines the global default regex engine. Defaults to `tree`.
current_global_engine(Engine) :-
    (   catch(user:regexp_engine(E), _, fail), nonvar(E) ->
        normalize_engine(E, Engine)
    ;   catch(user:regexp_mode(E), _, fail), nonvar(E) ->
        normalize_engine(E, Engine)
    ;   Engine = tree
    ).

%% current_static_engine(-Engine)
%
% Determines the engine used for compile-time static compilation.
% Checks user:regexp_static_engine/1, falling back to current_global_engine/1.
current_static_engine(Engine) :-
    (   catch(user:regexp_static_engine(E), _, fail), nonvar(E) ->
        normalize_engine(E, Engine)
    ;   current_global_engine(Engine)
    ).

%% current_dynamic_engine(-Engine)
%
% Determines the engine used for runtime dynamic pattern compilation and execution.
% Checks user:regexp_dynamic_engine/1, falling back to current_global_engine/1.
current_dynamic_engine(Engine) :-
    (   catch(user:regexp_dynamic_engine(E), _, fail), nonvar(E) ->
        normalize_engine(E, Engine)
    ;   current_global_engine(Engine)
    ).

%% current_regexp_engine(-Engine)
%
% Backward-compatible alias for current_global_engine/1.
current_regexp_engine(Engine) :-
    current_global_engine(Engine).

%% static_compilation_enabled
%
% True if compile-time static pattern compilation is active (the default).
% Fails if user:regexp_static_compilation(false/off) or user:regexp_expansion(false/off) is set.
static_compilation_enabled :-
    \+ static_compilation_disabled.

static_compilation_disabled :-
    catch(user:regexp_static_compilation(Val), _, fail),
    (Val == false ; Val == off).
static_compilation_disabled :-
    catch(user:regexp_expansion(Val), _, fail),
    (Val == false ; Val == off).

%% current_regexp_expansion(-Mode)
%
% Determines the active macro expansion mode. Defaults to `term` (Approach A).
current_regexp_expansion(Mode) :-
    (   catch(user:regexp_expansion(M), _, fail), nonvar(M) ->
        Mode = M
    ;   Mode = term
    ).

%% is_literal_pattern(@Pattern, -Chars)
%
% Checks whether `Pattern` is a ground literal (character list or atom),
% excluding already compiled automaton terms.
is_literal_pattern(Pattern, Chars) :-
    nonvar(Pattern),
    \+ is_compiled_structure(Pattern),
    (   chars_si(Pattern) -> Chars = Pattern
    ;   atom_si(Pattern)  -> atom_chars(Pattern, Chars)
    ).

is_compiled_structure(compiled_tree(_, _)).
is_compiled_structure(compiled(_, _)).
is_compiled_structure(nfa(_, _, _, _)).

%% compile_literal_pattern(+Engine, +Chars, -Compiled)
%
% Compiles a literal pattern character sequence into the engine's precompiled term structure.
compile_literal_pattern(EngineRaw, Chars, Compiled) :-
    normalize_engine(EngineRaw, Engine),
    compile_literal_pattern_norm(Engine, Chars, Compiled).

compile_literal_pattern_norm(tree, Chars, compiled_tree(Automaton, GroupCount)) :-
    pattern_ast(Chars, AST),
    compile_ast_tree(AST, Automaton, GroupCount).
compile_literal_pattern_norm(dcg, Chars, compiled(Goal, GroupCount)) :-
    pattern_ast(Chars, AST),
    ast_dcg_goal(AST, 0, GroupCount, Goal).
compile_literal_pattern_norm(dfa, Chars, NFA) :-
    pattern_ast(Chars, AST),
    compile_ast_dfa(AST, NFA, _).

%% expand_literal_goal(@Pattern, -Compiled)
%
% Helper for goal_expansion: verifies that static compilation is enabled,
% the expansion mode is `term`, the pattern is a literal, and compiles it via current_static_engine.
expand_literal_goal(Pattern, Compiled) :-
    static_compilation_enabled,
    current_regexp_expansion(term),
    is_literal_pattern(Pattern, Chars),
    current_static_engine(Engine),
    compile_literal_pattern(Engine, Chars, Compiled).

/* =========================================================================
   Approach A: Goal Expansion (Precompiled Term Inlining)
   ========================================================================= */

% Unqualified re_match/2
user:goal_expansion(re_match(Pattern, Input),
                    pure_regex:re_match(Compiled, Input)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match/2
user:goal_expansion(pure_regex:re_match(Pattern, Input),
                    pure_regex:re_match(Compiled, Input)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match/3
user:goal_expansion(re_match(Pattern, Input, Rest),
                    pure_regex:re_match(Compiled, Input, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match/3
user:goal_expansion(pure_regex:re_match(Pattern, Input, Rest),
                    pure_regex:re_match(Compiled, Input, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match/4 (DCG //1 expansion or direct)
user:goal_expansion(re_match(Pattern, Match, S0, S),
                    pure_regex:re_match(Compiled, Match, S0, S)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match/4
user:goal_expansion(pure_regex:re_match(Pattern, Match, S0, S),
                    pure_regex:re_match(Compiled, Match, S0, S)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match_groups/4
user:goal_expansion(re_match_groups(Pattern, Input, Match, Groups),
                    pure_regex:re_match_groups(Compiled, Input, Match, Groups)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match_groups/4
user:goal_expansion(pure_regex:re_match_groups(Pattern, Input, Match, Groups),
                    pure_regex:re_match_groups(Compiled, Input, Match, Groups)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match_groups/5
user:goal_expansion(re_match_groups(Pattern, Input, Match, Groups, Rest),
                    pure_regex:re_match_groups(Compiled, Input, Match, Groups, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match_groups/5
user:goal_expansion(pure_regex:re_match_groups(Pattern, Input, Match, Groups, Rest),
                    pure_regex:re_match_groups(Compiled, Input, Match, Groups, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match_named/4
user:goal_expansion(re_match_named(Pattern, Input, Match, Named),
                    pure_regex:re_match_named(Compiled, Input, Match, Named)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match_named/4
user:goal_expansion(pure_regex:re_match_named(Pattern, Input, Match, Named),
                    pure_regex:re_match_named(Compiled, Input, Match, Named)) :-
    expand_literal_goal(Pattern, Compiled).

% Unqualified re_match_named/5
user:goal_expansion(re_match_named(Pattern, Input, Match, Named, Rest),
                    pure_regex:re_match_named(Compiled, Input, Match, Named, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

% Module-qualified pure_regex:re_match_named/5
user:goal_expansion(pure_regex:re_match_named(Pattern, Input, Match, Named, Rest),
                    pure_regex:re_match_named(Compiled, Input, Match, Named, Rest)) :-
    expand_literal_goal(Pattern, Compiled).

/* =========================================================================
   Approach B: Term Expansion (DCG Rule Generation)
   ========================================================================= */

% Preferred mechanism once Trealla (and other engines) support macro expansion to a fixed point:
%   user:term_expansion(re_rule(HeadSpec//0, Pattern), (RuleHead --> Body)).
% For portable cross-engine compatibility with engines lacking a recursive DCG expansion pass after
% term_expansion, we expand directly into clause heads with explicit difference-list arguments (S0, S).

% re_rule(HeadSpec//0, Pattern)
user:term_expansion(re_rule(HeadSpec//0, Pattern), (ClauseHead :- phrase(Body, S0, S))) :-
    is_literal_pattern(Pattern, Chars),
    current_static_engine(Engine),
    compile_literal_pattern(Engine, Chars, Compiled),
    expand_rule_head(HeadSpec, Compiled, RuleHead, Body),
    make_dcg_clause_head(RuleHead, S0, S, ClauseHead).

% :- re_rule(HeadSpec//0, Pattern)
user:term_expansion((:- re_rule(HeadSpec//0, Pattern)), (ClauseHead :- phrase(Body, S0, S))) :-
    is_literal_pattern(Pattern, Chars),
    current_static_engine(Engine),
    compile_literal_pattern(Engine, Chars, Compiled),
    expand_rule_head(HeadSpec, Compiled, RuleHead, Body),
    make_dcg_clause_head(RuleHead, S0, S, ClauseHead).

% re_rule_named(HeadTerm//0, Pattern)
user:term_expansion(re_rule_named(HeadTerm//0, Pattern),
                    (ClauseHead :- phrase(pure_regex:re_match_named(Compiled, Match, Named), S0, S))) :-
    HeadTerm =.. [Name, _, _],
    atom_si(Name),
    is_literal_pattern(Pattern, Chars),
    current_static_engine(Engine),
    compile_literal_pattern(Engine, Chars, Compiled),
    RuleHead =.. [Name, Match, Named],
    make_dcg_clause_head(RuleHead, S0, S, ClauseHead).

% :- re_rule_named(HeadTerm//0, Pattern)
user:term_expansion((:- re_rule_named(HeadTerm//0, Pattern)),
                    (ClauseHead :- phrase(pure_regex:re_match_named(Compiled, Match, Named), S0, S))) :-
    HeadTerm =.. [Name, _, _],
    atom_si(Name),
    is_literal_pattern(Pattern, Chars),
    current_static_engine(Engine),
    compile_literal_pattern(Engine, Chars, Compiled),
    RuleHead =.. [Name, Match, Named],
    make_dcg_clause_head(RuleHead, S0, S, ClauseHead).

make_dcg_clause_head(RuleHead, S0, S, ClauseHead) :-
    RuleHead =.. [Name|Args],
    append(Args, [S0, S], FullArgs),
    ClauseHead =.. [Name|FullArgs].

expand_rule_head(Name, Compiled, RuleHead, pure_regex:re_match(Compiled)) :-
    atom_si(Name),
    RuleHead =.. [Name].
expand_rule_head(HeadTerm, Compiled, RuleHead, pure_regex:re_match(Compiled, Match)) :-
    HeadTerm =.. [Name, _],
    atom_si(Name),
    RuleHead =.. [Name, Match].
expand_rule_head(HeadTerm, Compiled, RuleHead, pure_regex:re_match_groups(Compiled, Match, Groups)) :-
    HeadTerm =.. [Name, _, _],
    atom_si(Name),
    RuleHead =.. [Name, Match, Groups].
