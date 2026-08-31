# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-08-31

### Added
- Created `src/pure_regex.pl` as primary module entry point (`:- module(pure_regex, [...]).`).
- Maintained `src/regexp.pl` as a backwards-compatible alias module.
- Added comprehensive test suites for public interface parity, AST parsing, time formatting, international Unicode characters, and TOML tokenization.

### Changed
- Renamed library package from `regexp` to `pure_regex` to avoid name collisions across Prolog ecosystems.
- Updated package manifests (`scryer-manifest.pl`, `pack.pl`, `bakage.toml`).
- Updated documentation and usage examples to reference `pure_regex`.

## [0.1.1] - 2026-08-29

### Changed
- Migrated repository structure to standard Prolog Agent Toolkit conventions.
- Relocated core modules into `src/core/`.
- Updated package manifests and testing harness.
