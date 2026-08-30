:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(library(charsio)).
:- use_module('../src/core/regexp_tree').

format_example(Pattern) :-
    re_tree_compile(Pattern, Compiled),
    format("Pattern: ~s~nCompiled:~n  ~w~n~n", [Pattern, Compiled]).

main :-
    format("=== Generated Rational Tree Automata Examples ===~n~n", []),
    format_example("a.*b"),
    format_example("a|b"),
    format_example("(a+)b"),
    format("=== End of Generated Examples ===~n", []).
