---
name: scryer-prolog-standards
description: Coding standards and guidelines for pure, ISO-compliant Scryer Prolog projects.
---

# Scryer Prolog Standards

These guidelines define the coding standards, style rules, and structural practices for Scryer Prolog in this repository.

## Core Implementation Rules
- **Implementation**: Always use Scryer Prolog (ISO-compliant).
- **Type tests**: Prefer using `library(si)` (e.g. `list_si/1`, `atom_si/1`, `chars_si/1`).
- **Strings**: Treat strings as lists of characters. `double_quotes` must always be `chars` (lists of characters), not strings or atoms.
- **DCGs**: Use pure DCG syntax for all parsing and matching logic. Look for opportunities to use DCGs.
- **Purity**: Prefer `dif/2` (from `library(dif)`) and `if_/3` (from `library(reif)`) to maintain logical purity. Avoid the cut-fail operator `->` when `if_/3` can be used. Prefer `clpz` and `clpb` over impure arithmetic predicates where applicable.

## Testing & Packaging
- **Framework**: Use `pkg(testing)` from `bakage` for all test suites.
- **Bakage**: Packages use `bakage`. Refer to `scryer-manifest.pl` for dependencies.

## Style Guidelines
- **Value Separation**: When testing a condition to generate a value and then using that value, prefer to test and generate the value in the condition, and use the value *after* the condition.
  - *Example*: `if_(G, A = "A", A = "B"), write(A)` is preferred over writing `write(A)` in each branch.
- **DRY Principle**: Avoid code repetition. Use Prolog expansion mechanisms or assert statements.
- **Logging**: Use the project's custom logging module (`logs.pl`) for diagnostics meant to be left in and activated at runtime.
- **Standards Referencing**: See Covington rules in the references directory for further style details.

## DocLog Documentation Conventions

All public interface predicates and modules must be documented using **DocLog** conventions (which support Djot markup syntax).

### 1. Module Documentation
Every module must begin with a doclog block comment `/** ... */` detailing its purpose, usage examples, and high-level design:
```prolog
/**
  Provides backtracking/DCG based regular expression compiler and matching.

  This module compiles a regular expression AST into a Scryer Prolog DCG representation.
*/
:- module(regexp_dcg, [ ... ]).
```

### 2. Predicate Documentation
Every exported predicate must have a doclog block immediately preceding its definition.
- The block starts with `%%` followed by `%` lines.
- The first line specifies the predicate signature with arguments and **mode indicators**:
  - `+` for inputs
  - `-` for outputs
  - `?` for either
- A blank line `%` separates the signature from the description.
- Djot markup can be used within descriptions.

#### Standard Predicate Example:
```prolog
%% re_match(+Pattern, +Input, -Match)
%
% Match the given regular expression `Pattern` against the `Input` string.
% `Match` is unified with the full matched substring.
```

#### DCG Non-Terminal Example:
For Definite Clause Grammar non-terminals, append `//` to the predicate signature line:
```prolog
%% re_match_dcg(+Pattern, -Match)//
%
% Match the given regular expression `Pattern` against the input stream.
```

