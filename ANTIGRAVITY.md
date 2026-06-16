# Project: Regex Parser & Recognizer
- **Current Task:** Building a Python-style logging module (`logger.pl`).
- **Goal:** Learn "vibe coding" by describing intent rather than syntax.
- **Style Guidelines:** Refer to [prolog_guidelines.md](prolog_guidelines.md) and [covington_style.md](covington_style.md) for coding standards.

## Testing Practices
- **Framework**: We use the `pkg(testing)` package from `bakage`.
- **Location**: Unit tests are located in `tests/test_*.pl` files (e.g., [test_regexp_ast.pl](tests/test_regexp_ast.pl)).
- **Running Tests**:
  - Run all tests via the [Makefile](Makefile): `make test`
  - Run a specific test suite: `make test_<name>` (e.g. `make test_regexp_ast`)
  - Run manually:
    - `nice scryer-safe -g run_tests -g halt tests/test_<name>.pl` (for `pkg(testing)` suites)
    - `nice scryer-safe -g main tests/test_logs.pl` (for custom `main` suites)