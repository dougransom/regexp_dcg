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
- **Verification & Testing**: Always run `make test` to verify changes.
  - **Bug Fixes**: Always add a test case demonstrating the bug (failing prior to the fix) alongside any bug fix.
  - **New Interfaces**: Always add unit tests for new public predicates, interfaces, or features.
