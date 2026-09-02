# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
> Historical releases prior to August 31, 2026 have been re-indexed into the `0.1.0.devX` series (`v0.1.0.dev1` through `v0.1.0.dev4`) leading up to the official `0.1.0` stable release. Older commit snapshots may show superseded version strings in historical manifests.

## [0.1.0.dev7] - 2026-09-02

### Added
- Bidirectional pattern generation: `re_match/2-3` can now generate valid character lists when the input is an unbound variable (e.g. `re_match("aa?b", X)` producing `"aab"` and `"ab"`, `re_match("a.b", X)` producing `[a, Y, b]`).
- Incremental enumeration for Kleene star (`*`) and plus (`+`) during pattern generation to avoid infinite recursion.
- Dedicated automated bidirectional unit test suite (`tests/scryer/test_bidirectional.pl`).
- Bidirectional pattern generation documentation and examples in `README.md` and `llms.txt`.
- Automated interface docstring parity tests in `tests/scryer/test_exports_match.pl` verifying 1:1 docstrings across all engine modules.
- Interface documentation consistency policy in `.agents/AGENTS.md`.

### Changed
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
