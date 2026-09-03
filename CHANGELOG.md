# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
> Historical releases prior to August 31, 2026 have been re-indexed into the `0.1.0.devX` series (`v0.1.0.dev1` through `v0.1.0.dev4`) leading up to the official `0.1.0` stable release. Older commit snapshots may show superseded version strings in historical manifests.

## [0.1.1.dev1] - Unreleased

## [0.1.0] - 2026-09-03

### Added
- Trealla Prolog support alongside Scryer Prolog following ISO Prolog standards and Triska's "ISO Core + Engine Shim" architecture.
- Dedicated Trealla test suites in `tests/trealla/` matching all Scryer test suites (15 test suites, 260+ tests passing with 0 failures).
- Multi-engine Makefile test target supporting `make test PROLOG_ENGINE=trealla` (via `trealla-safe`) and `make test PROLOG_ENGINE=scryer` (via `scryer-safe`).
- Triska-style loader shim in `tests/trealla/trealla_loader.pl` dynamically resolving Scryer file-relative module imports and rewriting `Name//Arity` indicators in import lists.
- Trealla compatibility badge and runtimePlatform metadata in `README.md` and `codemeta.json`.

### Changed
- AST tokenizer macro expansion in `src/core/regexp_ast.pl` (`tk/2`, `ci/2`) generating difference list clause heads directly for cross-engine compatibility with systems lacking recursive DCG expansion passes; documented preferred `-->` macro syntax in comments.
- Static DCG rule term expansion in `src/core/regexp_expansion.pl` (`re_rule//0`, `re_rule_named//0`) generating difference list clause heads directly with difference list arguments; documented preferred `-->` macro syntax in comments.
- Refactored DFA group and named extraction in `src/core/regexp_compile_dfa.pl` (`re_match_groups_dcg/5`, `re_match_named_dcg/5`) from pushback DCG syntax to standard ISO difference list clause heads.
- Guarded pattern cache manager `get_or_compile_pattern/5` in `src/core/regexp_common.pl` with `var_t` check to raise `instantiation_error` on unbound variables before querying dynamic cache.

## [0.1.0.dev7] - 2026-09-02

### Added
- Compile-time static regex compilation in `src/core/regexp_expansion.pl`:
  - **Approach A (`goal_expansion/2`)**: Compiles literal patterns (`"..."` or `'...'`) at load time and inlines the compiled automaton structure directly as constant terms into clause bytecode, completely bypassing the dynamic pattern cache.
  - **Approach B (`term_expansion/2`)**: Translates `re_rule//0` and `re_rule_named//0` declarations into dedicated, named Prolog DCG grammar rules.
- Declarative configuration modes and overrides:
  - `user:regexp_engine/1` (and `user:regexp_mode/1`): Sets default matching engine (`rt` / `tree` vs `dcg`).
  - `user:regexp_static_compilation/1` (and `user:regexp_expansion/1`): Toggles compile-time static compilation (`true` / `false` or `on` / `off`).
  - `user:regexp_static_engine/1`: Overrides matching engine specifically for compile-time static compilation.
  - `user:regexp_dynamic_engine/1`: Overrides matching engine specifically for runtime dynamic pattern matching.
- Dedicated unit test suite for macro expansion and modes (`tests/scryer/test_expansion.pl`).
- Bidirectional pattern generation: `re_match/2-3` can now generate valid character lists when the input is an unbound variable (e.g. `re_match("aa?b", X)` producing `"aab"` and `"ab"`, `re_match("a.b", X)` producing `[a, Y, b]`).
- Incremental enumeration for Kleene star (`*`) and plus (`+`) during pattern generation to avoid infinite recursion.
- Dedicated automated bidirectional unit test suite (`tests/scryer/test_bidirectional.pl`).
- Bidirectional pattern generation documentation and examples in `README.md` and `llms.txt`.
- Automated interface docstring parity tests in `tests/scryer/test_exports_match.pl` verifying 1:1 docstrings across all engine modules.
- Interface documentation consistency policy in `.agents/AGENTS.md`.

### Changed
- Dynamic engine routing in `src/pure_regex.pl` cleanly dispatching to `re_tree_*` or `re_dcg_*` without module namespace collisions.
- Fixed module references in `examples/compare_performance.pl` (`regexp_compile_dcg` and `regexp_compile_dfa`).
- Introduced `to_input_chars/2` in `src/core/regexp_common.pl` implementing the `can_be(chars, Input)` contract.
- Cleaned up doc comment headings in `src/pure_regex.pl` to eliminate false positive reports from `prolog-safe`.
- Synchronized canonical predicate-level docstrings across `src/pure_regex.pl`, `src/core/regexp_tree.pl`, `src/core/regexp_compile_dcg.pl`, and `src/core/regexp_compile_dfa.pl`.
- Documented `re_clear_cache/0` across usage guides and docstrings as intended for rare circumstances where an excessive number of compiled patterns cause high memory usage.

## [0.1.0.dev6] - 2026-08-31

### Added
- Added `llms.txt` discovery badge to `README.md`.
- Added declarative DCG Tokenizer & Lexer recipe and Engine Selection guide to `llms.txt`.
- Expanded `.agents/AGENTS.md` with complete architecture map, fast single-test execution commands, and ISO Prolog purity standards.

## [0.1.0.dev5] - 2026-08-31

### Changed
- Comprehensive documentation audit: updated all module paths (`src/core/`), import snippets, and unit test references across `README.md`, `llms.txt`, and `schema.jsonld`.
- Synchronized package and build metadata for HTML and LLM tooling.

## [0.1.0.dev4] - 2026-08-31

### Added
- Added project-specific release policy in `.agents/AGENTS.md` ensuring development vs. final release modes are explicitly clarified.
- Re-indexed release series to `0.1.0.devX`.

## [0.1.0.dev3] - 2026-08-31

### Added
- Created `src/pure_regex.pl` as primary module entry point (`:- module(pure_regex, [...]).`).
- Maintained `src/regexp.pl` as a backwards-compatible alias module.
- Added comprehensive test suites for public interface parity, AST parsing, time formatting, international Unicode characters, and TOML tokenization.

### Changed
- Renamed library package from `regexp` to `pure_regex` to avoid name collisions across Prolog ecosystems.
- Updated package manifests (`scryer-manifest.pl`, `pack.pl`).
- Updated documentation and usage examples to reference `pure_regex`.

## [0.1.0.dev2] - 2026-08-29

### Changed
- Migrated repository structure to standard Prolog Agent Toolkit conventions.
- Relocated core modules into `src/core/`.
- Updated package manifests and testing harness.

## [0.1.0.dev1] - 2026-08-29

### Added
- Initial adoption of standard agent toolkit conventions and pure ISO Prolog rational tree and DCG matching engine baseline.
