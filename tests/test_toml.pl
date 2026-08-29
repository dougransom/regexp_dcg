:- use_module(testing).
:- use_module(library(pio)).
:- use_module(library(dcgs)).
:- use_module('../examples/toml/toml_tokenizer').
:- use_module('../examples/toml/toml_parser').

read_file_chars([]) --> [].
read_file_chars([C|Cs]) --> [C], read_file_chars(Cs).

test("TOML: tokenize and parse sample.toml into AST",
    (   phrase_from_file(read_file_chars(Chars), "examples/toml/sample.toml"),
        tokenize_toml(Chars, Tokens),
        parse_toml_tokens(Tokens, AST),
        AST = toml(Entries),
        member(kv(["title"], string("My App")), Entries),
        member(kv(["count"], number(42)), Entries),
        member(kv(["debug"], boolean(true)), Entries),
        member(table(["server"]), Entries),
        member(kv(["database", "host"], string("db.local")), Entries)
    )).
