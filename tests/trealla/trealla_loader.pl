:- module(trealla_loader, []).

/**
  Trealla Prolog compatibility loader / engine shim.

  Follows Triska's ISO core + engine shims convention (Prolog Conventions, Section 18).
  This shim rewrites file-relative module imports used by Scryer to project-root-relative
  paths in Trealla, and translates DCG '//' indicators in import lists into predicate arities.
*/

user:term_expansion((:- use_module(Spec, Imports0)), (:- use_module(TargetSpec, Imports))) :-
    map_trealla_spec(Spec, TargetSpec),
    map_trealla_imports(Imports0, Imports).

user:term_expansion((:- use_module(Spec)), (:- use_module(TargetSpec))) :-
    map_trealla_spec(Spec, TargetSpec).

map_trealla_spec('core/regexp_tree', 'src/core/regexp_tree').
map_trealla_spec('core/regexp_compile_dcg', 'src/core/regexp_compile_dcg').
map_trealla_spec('core/regexp_common', 'src/core/regexp_common').
map_trealla_spec('core/regexp_expansion', 'src/core/regexp_expansion').
map_trealla_spec(regexp_ast, 'src/core/regexp_ast').
map_trealla_spec(regexp_common, 'src/core/regexp_common').
map_trealla_spec(regexp_compile_tree, 'src/core/regexp_compile_tree').
map_trealla_spec(regexp_compile_dcg, 'src/core/regexp_compile_dcg').
map_trealla_spec(regexp_compile_dfa, 'src/core/regexp_compile_dfa').
map_trealla_spec(regexp_tree, 'src/core/regexp_tree').
map_trealla_spec('../../src/pure_regex', 'src/pure_regex').
map_trealla_spec('../../src/core/regexp_tree', 'src/core/regexp_tree').
map_trealla_spec('../../src/core/regexp_compile_dcg', 'src/core/regexp_compile_dcg').
map_trealla_spec('../../src/core/regexp_compile_dfa', 'src/core/regexp_compile_dfa').
map_trealla_spec('../../src/core/regexp_ast', 'src/core/regexp_ast').
map_trealla_spec('../../src/core/regexp_common', 'src/core/regexp_common').
map_trealla_spec('../testing', 'tests/testing').
map_trealla_spec('../portable/test_regexp_compile_shared', 'tests/portable/test_regexp_compile_shared').

map_trealla_imports([], []).
map_trealla_imports([Name//Arity|Rest], [Name/RealArity|MappedRest]) :-
    !,
    RealArity is Arity + 2,
    map_trealla_imports(Rest, MappedRest).
map_trealla_imports([I|Rest], [I|MappedRest]) :-
    map_trealla_imports(Rest, MappedRest).
