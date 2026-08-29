:- use_module('../testing').
:- use_module(library(lists)).

% Helper to read the exports list from the module declaration of a file
module_exports(File, Exports) :-
    open(File, read, Stream),
    read(Stream, Term),
    close(Stream),
    Term = (:- module(_, Exports)).

test("Public user interfaces are identical across all modules",
    (   % Expected public API predicates
        PublicInterface = [
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
        ],
        % Read exports from active engine files
        module_exports('src/regexp.pl', RegexpExports),
        module_exports('src/core/regexp_compile_dfa.pl', DfaExports),
        module_exports('src/core/regexp_tree.pl', TreeExports),

        % 1. All public interface predicates must be exported by regexp.pl
        maplist(member_of(RegexpExports), PublicInterface),
        
        % 2. All public interface predicates must be exported by the DFA engine
        maplist(member_of(DfaExports), PublicInterface),
        
        % 3. All public interface predicates must be exported by the Tree engine
        maplist(member_of(TreeExports), PublicInterface),

        % 4. The DFA engine must ONLY export the public user interface
        length(DfaExports, L_Dfa),
        length(PublicInterface, L_Pub),
        L_Dfa == L_Pub
    )).

member_of(List, Element) :-
    member(Element, List).
