# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!NOTE]
> Historical releases prior to August 31, 2026 have been re-indexed into the `0.1.0.devX` series (`v0.1.0.dev1` through `v0.1.0.dev4`) leading up to the official `0.1.0` stable release. Older commit snapshots may show superseded version strings in historical manifests.

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
- Updated package manifests (`scryer-manifest.pl`, `pack.pl`, `bakage.toml`).
- Updated documentation and usage examples to reference `pure_regex`.

## [0.1.0.dev2] - 2026-08-29

### Changed
- Migrated repository structure to standard Prolog Agent Toolkit conventions.
- Relocated core modules into `src/core/`.
- Updated package manifests and testing harness.

## [0.1.0.dev1] - 2026-08-29

### Added
- Initial adoption of standard agent toolkit conventions and pure ISO Prolog rational tree and DCG matching engine baseline.
