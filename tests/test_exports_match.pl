:- use_module('../bakage').
:- use_module(pkg(testing)).
:- use_module(library(lists)).

% Helper to read the exports list from the module declaration of a file
module_exports(File, Exports) :-
    open(File, read, Stream),
    read(Stream, Term),
    close(Stream),
    Term = (:- module(_, Exports)).

test("Public user interfaces are identical in both modules",
    (   % Expected public API predicates
        PublicInterface = [
            re_match//1,
            re_match//2,
            re_match_groups//3,
            re_match_named//3,
            re_group/3,
            re_compile/2,
            re_clear_cache/0
        ],
        % Read exports from both files (assuming execution from root directory)
        module_exports('regexp_dcg.pl', DcgExports),
        module_exports('src/regexp_compile_dfa.pl', DfaExports),
        
        % 1. All public interface predicates must be exported by the DCG engine
        maplist(member_of(DcgExports), PublicInterface),
        
        % 2. All public interface predicates must be exported by the DFA engine
        maplist(member_of(DfaExports), PublicInterface),
        
        % 3. The DFA engine must ONLY export the public user interface
        length(DfaExports, L_Dfa),
        length(PublicInterface, L_Pub),
        L_Dfa == L_Pub
    )).

member_of(List, Element) :-
    member(Element, List).
