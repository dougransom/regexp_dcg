---
name: regexp-pattern-extensions
description: Guidelines for extending regular expression pattern support in the regexp_ast parser and updating documentation.
---

# Regular Expression Pattern Extensions

This skill provides guidelines and steps for extending regular expression pattern support in this project. Whenever a new regex feature (metacharacter, quantifier, anchor, group, or assertion) is added to the codebase, the documentation and test suites must be synchronized across all engines.

## Workflow for Adding New Patterns

1. **Implement Tokenizer Rules**:
   Add new token definitions to `re_token/1` or character class parsing in `src/core/regexp_ast.pl`.

2. **Implement AST Builders & Engines**:
   Add rules for AST construction in `src/core/regexp_ast.pl` and define matching behavior across all engine implementations:
   - Rational Tree Automaton (`src/core/regexp_compile_tree.pl` & `src/core/regexp_tree.pl`)
   - DCG engine (`src/core/regexp_compile_dcg.pl`)
   - DFA engine (`src/core/regexp_compile_dfa.pl` where applicable)

3. **Update & Synchronize Module Documentation**:
   You must update the **Supported Regular Expression Syntax** table in the header doclog comments to keep them consistent across:
   - Primary matching interface (`src/regexp.pl`)
   - Rational Tree Automaton engine (`src/core/regexp_tree.pl`)
   - DCG engine (`src/core/regexp_compile_dcg.pl`)
   - DFA engine (`src/core/regexp_compile_dfa.pl`)

   Ensure the new feature category, syntax, and description are added to the markdown table in each file.

4. **Write Unit Tests**:
   Add comprehensive test coverage in the relevant test files (`tests/scryer/test_regexp_ast.pl`, `tests/portable/test_regexp_compile_shared.pl`, `tests/scryer/test_regexp_tree.pl`) to verify both positive and negative matching scenarios across all engines.
