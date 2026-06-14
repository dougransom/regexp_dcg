# Project: Regex Parser & Recognizer
- **Current Task:** Building a Python-style logging module (`logger.pl`).
- **Goal:** Learn "vibe coding" by describing intent rather than syntax.
- **Style Guidelines:** Refer to [prolog_guidelines.md](prolog_guidelines.md) and [covington_style.md](covington_style.md) for coding standards.

## Testing Practices
- **Framework**: We use the `pkg(testing)` package from `bakage`.
- **Location**: Unit tests are located in `test_*.pl` files (e.g., [test_regexp_ast.pl](test_regexp_ast.pl)).
- **Running Tests**:
  - Run a `pkg(testing)` suite: `nice scryer-safe -g run_tests -g halt test_<name>.pl`
  - Run other tests (e.g., logging): `nice scryer-safe -g main test_logs.pl` (or just `nice scryer-safe test_logs.pl` if it has a `main` entrypoint that halts).