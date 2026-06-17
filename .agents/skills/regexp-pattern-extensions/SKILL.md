---
name: regexp-pattern-extensions
description: Guidelines for extending regular expression pattern support in the regexp_ast parser and updating documentation.
---

# Regular Expression Pattern Extensions

This skill provides guidelines and steps for extending regular expression pattern support in this project. Whenever a new regex feature (metacharacter, quantifier, anchor, group, or assertion) is added to the codebase, the documentation must be synchronized.

## Workflow for Adding New Patterns

1. **Implement Tokenizer Rules**:
   Add new token definitions to `re_token/1` or character class parsing in `regexp_ast.pl`.

2. **Implement AST Builders**:
   Add rules for AST construction in `regexp_ast.pl` and define the matching combinator behavior in `regexp_compile_dcg.pl` (and `regexp_compile_dfa.pl` where applicable).

3. **Update Module Documentation**:
   You must update the **Supported Regular Expression Syntax** table in the module documentation of `regexp_compile_dcg.pl` (specifically the header doclog comment). Ensure the new feature category, syntax, and description are added to the markdown table.

4. **Verify the Module Reference**:
   Ensure that the module documentation in `regexp_compile_dfa.pl` continues to reference the updated list in `regexp_compile_dcg.pl`.

5. **Write Unit Tests**:
   Add comprehensive test coverage in the relevant test files (`tests/test_regexp_ast.pl`, `tests/test_regexp_compile_dcg.pl`, etc.) to verify both positive and negative matching scenarios.
