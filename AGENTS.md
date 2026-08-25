# Scryer Prolog Repository Guidelines & Standards

When writing, refactoring, or reviewing Prolog code for this repository, all AI assistants and developers MUST adhere to the ISO Scryer Prolog standards defined in:

- **Core Scryer Prolog Standards**: [.agents/skills/scryer-prolog-standards/SKILL.md](.agents/skills/scryer-prolog-standards/SKILL.md)
- **Covington & Scryer References**: [.agents/skills/scryer-prolog-standards/references/](.agents/skills/scryer-prolog-standards/references/)
- **Pattern Extensions**: [.agents/skills/regexp-pattern-extensions/SKILL.md](.agents/skills/regexp-pattern-extensions/SKILL.md)

## Summary of Core Rules
- **Implementation**: Always use Scryer Prolog (ISO-compliant). Never use SWI-Prolog specifics like dicts, string types, or `is_list/1`.
- **Type Tests**: Prefer `library(si)` (`list_si/1`, `atom_si/1`, `chars_si/1`).
- **Strings**: Treat strings as lists of characters (`chars`). `double_quotes` must always be set to `chars`.
- **Libraries**: Explicitly import `:- use_module(library(dcgs)).` and `:- use_module(library(charsio)).`.
- **DCGs**: Use pure DCG syntax for all parsing and matching logic.
- **Purity**: Prefer `dif/2` (`library(dif)`) and `if_/3` (`library(reif)`). Avoid `->` when `if_/3` can be used.
- **Safety & Command Invocations**: ALL Prolog executions MUST use `prolog-safe` / `scryer-safe` wrappers or `$(SCRYER)` from the Makefile (enforcing `MemoryMax=50M`, `CPUQuota=65%`, `nice -n 19`, and `timeout 20s`). AI assistants MUST NEVER invoke raw Prolog binaries (`scryer-prolog`, `swipl`, `tpl`, `gprolog`, `ciao`) directly.
  - **Specifying Engine**: Set `PROLOG_ENGINE` environment variable (e.g. `export PROLOG_ENGINE=scryer`, `export PROLOG_ENGINE=swi`, `export PROLOG_ENGINE=trealla`).
- **Verification & Testing**: Always run `make test` to verify changes.
  - **Bug Fixes**: Always add a test case demonstrating the bug (failing prior to the fix) alongside any bug fix.
  - **New Interfaces**: Always add unit tests for new public predicates, interfaces, or features.

## Engine Interface Consistency Rule
All regular expression engines (`regexp_dcg.pl`, `src/regexp_compile_dfa.pl`, `regexp_tree.pl`) MUST maintain identical public user interfaces:
- **DCG Non-Terminal Predicates**: `re_match//1`, `re_match//2`, `re_match_groups//3`, `re_match_named//3`
- **Direct List Matchers**: `re_match/2`, `re_match/3`, `re_match_groups/4`, `re_match_groups/5`, `re_match_named/4`, `re_match_named/5`
- **Management & Utilities**: `re_group/3`, `re_compile/2`, `re_clear_cache/0`, `re_cache_info/2`

Whenever adding or modifying a public user interface predicate in one engine, you MUST update all other engines to maintain 1:1 API parity. This consistency is automatically enforced by `tests/test_exports_match.pl` during `make test`.

## Release & Versioning Workflow
When a release is requested by the user, AI assistants MUST follow these steps:
1. **Show Current Version & Prompt**: Read `scryer-manifest.pl`, display the current `version("...")` value to the user, and ask what version number and Git tag to use for the release.
2. **Sync Manifest & Git Tag**: Update `version("X.Y.Z")` in `scryer-manifest.pl` so it matches the Git tag (e.g. tag `v0.1.0` matches `version("0.1.0")`).
3. **Tag & Push**: Commit `scryer-manifest.pl`, create the annotated Git tag (e.g. `git tag -a v0.1.0 -m "Release v0.1.0"`), and push both commits and tags (`git push && git push origin v0.1.0`).
4. **Post-Release Dev Version Prompt**: Immediately after the release, ask the user if they want to set a new development version in `scryer-manifest.pl` with `.devX` (where `X` is an integer, e.g. `version("0.1.1.dev1")`).
