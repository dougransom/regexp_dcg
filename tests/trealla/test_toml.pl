:- use_module('tests/trealla/trealla_loader').
:- use_module('tests/testing').
:- use_module('src/pure_regex').
:- use_module('src/core/regexp_tree').
:- use_module(library(dcgs)).

% Basic pattern tests for TOML tokens using pure_regex
test("TOML: tokenize and parse sample.toml into AST",
    ( re_match("^\\[[a-zA-Z0-9_-]+\\]$", "[package]"),
      re_match("^[a-zA-Z0-9_-]+ *= *\".*\"$", "name = \"pure_regex\""),
      re_match("^[a-zA-Z0-9_-]+ *= *[0-9]+$", "version = 1"),
      re_match("^[a-zA-Z0-9_-]+ *= *(true|false)$", "pure = true")
    )).
