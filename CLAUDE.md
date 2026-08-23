# Claude Code Instructions

Please follow the Scryer Prolog standards and project guidelines defined in [AGENTS.md](file://AGENTS.md) and [.agents/skills/scryer-prolog-standards/SKILL.md](file://.agents/skills/scryer-prolog-standards/SKILL.md).

## Quick Reference
- **Run Tests**: `make test` (or `SCRYER="nice scryer-safe" make test`)
- **Generate Intro Documentation**: `nice scryer-safe -g main -g halt generate_intro_md.pl`
- **Primary Interface Module**: [regexp_dcg.pl](file://regexp_dcg.pl)
- **Internal Modules**: [src/regexp_ast.pl](file://src/regexp_ast.pl), [src/regexp_compile_dfa.pl](file://src/regexp_compile_dfa.pl), [src/logs.pl](file://src/logs.pl)
