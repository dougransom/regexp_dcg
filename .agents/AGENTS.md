# Project-Specific Agent Rules for pure_regex

## Release & Versioning Policy
- **Clarify Release Mode**: Whenever instructed to release (e.g. "release", "make a release", "cut a release"), ALWAYS ask the user explicitly whether this is a **dev release** (e.g. `X.Y.Z.devN`) or a **final/stable release** (e.g. `X.Y.Z`), and confirm the exact version number before proceeding.

## AI Agent Toolkit Integration
- **Toolkit Integration**: Shared Prolog standards, skills, and guidelines are loaded globally via the assistant configuration (e.g. `~/.gemini/config/skills.json` or `~/.agents/skills`) rather than embedded Git submodules.
- **Local Project Skills**: Repository-specific skills are maintained directly under `.agents/skills/`.

## Architecture & Matching Engines
- **Main Entry Point**: `src/pure_regex.pl` (`pure_regex`) — Re-exports the rational tree engine by default.
- **Rational Tree Automaton (`src/core/regexp_tree.pl`)**: Default engine. Pure, deterministic `if_/3`-driven cyclic term finite state automaton. Best for linear patterns with maximum speed and no choicepoints.
- **DCG Backtracking Engine (`src/core/regexp_compile_dcg.pl`)**: Full-featured engine supporting capture groups (`re_match_groups/4`), named groups (`re_match_named/4`), lookaheads (`(?=...)`, `(?!...)`), and inline flags.
- **DFA Engine (`src/core/regexp_compile_dfa.pl`)**: Deterministic finite automaton engine built via subset construction.
- **AST Parser (`src/core/regexp_ast.pl`)**: Parses regex pattern `chars` into an intermediate AST.

## Testing & Verification Commands
Always test changes using `scryer-safe` (or `nice scryer_safe`) to avoid OS resource exhaustion:
- **Run all tests**: `make test`
- **Single test suite execution**:
  - `scryer-safe -g run_tests -g halt tests/scryer/test_regexp.pl`
  - `scryer-safe -g main -g halt tests/scryer/test_regexp_tree.pl`
  - `scryer-safe -g run_tests -g halt tests/scryer/test_regexp_dcg.pl`
  - `scryer-safe -g run_tests -g halt tests/scryer/test_regexp_ast.pl`
  - `scryer-safe -g run_tests -g halt tests/scryer/test_toml.pl`
- **Rebuild documentation**: `make docs` (regenerates `docs/usage.md` and `llms-full.txt`)

## Scryer & ISO Prolog Coding Standards
- **Strings as Chars**: All string operations treat strings as lists of characters (`chars`).
- **Logical Purity**: Use `if_/3` and `dif/2` from `library(reif)`. Avoid cut (`!`) in DCG non-terminals where `if_` maintains determinism.
- **Type Tests**: Use `library(si)` (e.g. `atom_si/1`, `list_si/1`).
- **Prohibited SWI Constructs**: Never use SWI-specific `dicts`, `string` type, or `is_list/1`.
- **Structured Context**: Refer to `llms.txt`, `llms-full.txt`, and `codemeta.json` for machine-readable interface specifications.
