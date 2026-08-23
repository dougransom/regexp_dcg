# Claude Code Instructions

Please follow the Scryer Prolog standards and project guidelines defined in [AGENTS.md](AGENTS.md) and [.agents/skills/scryer-prolog-standards/SKILL.md](.agents/skills/scryer-prolog-standards/SKILL.md).

## Quick Reference
- **Run Tests**: `make test` (or `SCRYER="nice scryer-safe" make test`)
- **Generate Intro Documentation**: `nice scryer-safe -g main -g halt generate_intro_md.pl`
- **Primary Interface Module**: [regexp_dcg.pl](regexp_dcg.pl)
- **Internal Modules**: [src/regexp_ast.pl](src/regexp_ast.pl), [src/regexp_compile_dfa.pl](src/regexp_compile_dfa.pl), [src/logs.pl](src/logs.pl)
