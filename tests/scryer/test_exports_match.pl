:- use_module('../testing').
:- use_module(library(lists)).
:- use_module(library(pio)).
:- use_module(library(dcgs)).

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
        module_exports('src/pure_regex.pl', PureRegexpExports),
        module_exports('src/core/regexp_compile_dfa.pl', DfaExports),
        module_exports('src/core/regexp_compile_dcg.pl', DcgExports),
        module_exports('src/core/regexp_tree.pl', TreeExports),

        % 1. All public interface predicates must be exported by pure_regex.pl
        maplist(member_of(PureRegexpExports), PublicInterface),
        
        % 2. All public interface predicates must be exported by the DFA engine
        maplist(member_of(DfaExports), PublicInterface),

        % 3. All public interface predicates must be exported by the DCG engine
        maplist(member_of(DcgExports), PublicInterface),
        
        % 4. All public interface predicates must be exported by the Tree engine
        maplist(member_of(TreeExports), PublicInterface),

        % 5. The DFA engine must export the public user interface (plus internal compiler hook)
        select(compile_ast_dfa/3, DfaExports, DfaPubOnly) ->
            ( length(DfaPubOnly, L_Dfa),
              length(PublicInterface, L_Pub),
              L_Dfa == L_Pub )
        ;   ( length(DfaExports, L_Dfa),
              length(PublicInterface, L_Pub),
              L_Dfa == L_Pub )
    )).

test("Public interface predicate docstrings are consistent across all modules",
    (   Files = [
            'src/pure_regex.pl',
            'src/core/regexp_tree.pl',
            'src/core/regexp_compile_dcg.pl',
            'src/core/regexp_compile_dfa.pl'
        ],
        RequiredDocPrefixes = [
            "%% re_match",
            "%% re_match_groups",
            "%% re_match_named",
            "%% re_group",
            "%% re_compile",
            "%% re_clear_cache",
            "%% re_cache_info"
        ],
        maplist(file_contains_all_docstrings(RequiredDocPrefixes), Files)
    )).

file_contains_all_docstrings(DocPrefixes, File) :-
    phrase_from_file(seq(Chars), File),
    maplist(chars_contain(Chars), DocPrefixes).

chars_contain(Chars, DocPrefix) :-
    phrase((any_seq, seq(DocPrefix), any_seq), Chars).

any_seq --> [].
any_seq --> [_], any_seq.

member_of(List, Element) :-
    member(Element, List).
