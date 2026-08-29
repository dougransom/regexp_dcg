# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2.dev1] - 2026-08-29

### Changed
- Migrated repository structure to standard Prolog Agent Toolkit conventions.
- Relocated core modules `regexp_dcg.pl` and `regexp_tree.pl` into `src/`.
- Replaced legacy `scryer-manifest.pl` and procedural `bakage.pl` with declarative manifests (`bakage.toml`, `pack.pl`).
- Scaffolding `tests/testing.pl` test runner harness.
