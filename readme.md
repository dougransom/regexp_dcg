# Regular Expression Engine for Scryer Prolog and ISO Prolog Systems (`regexp_dcg`)

A pure, ISO-compliant Definite Clause Grammar (DCG) regular expression engine designed for [Scryer Prolog](https://github.com/mthom/scryer-prolog) and other ISO-compliant Prolog implementations.

### Project Goals

The primary goal of this project is to provide a portable, pure, ISO-compliant Regular Expression (`REGEXP`) matching library for Scryer Prolog and other ISO Prolog systems (such as Trealla Prolog, Tau Prolog, GNU Prolog, Ciao, etc.) using pure DCG non-terminals without relying on system-dependent primitives.  

---

## Packaging & Installation

Bakage is **optional**. Because `regexp_dcg` is written in pure ISO Prolog, you can use it either with Bakage or by directly importing the files into any Prolog project.

### Option 1: With Bakage Package Manager ([`bakage`](https://github.com/bakaq/bakage))

1. **Add to `scryer-manifest.pl`**:
   ```prolog
   dependencies([
       dependency("regexp", git("https://github.com/dougransom/regexp_dcg.git"))
   ]).
   ```

2. **Install Dependencies**:
   ```bash
   scryer-prolog bakage.pl -- install
   ```

3. **Import in Prolog Code**:
   ```prolog
   :- use_module(bakage).
   :- use_module(pkg(regexp)).

   ?- phrase(re_match("[a-z]+", Match), "hello").
   ```

### Option 2: Without Bakage (Direct Import / Git Clone)

1. **Clone or Download the Repository**:
   ```bash
   git clone https://github.com/dougransom/regexp_dcg.git
   ```

2. **Direct Import via `use_module/1`**:
   Import `regexp_dcg.pl` using its relative path (or place `regexp_dcg.pl` and `regexp_ast.pl` in your source directory / `SCRYER_PATH`):

   ```prolog
   :- use_module('path/to/regexp_dcg/regexp_dcg').

   ?- phrase(re_match("[a-z]+", Match), "hello").
   ```

---

## Primary Interface (`regexp_dcg`)

The main entry point for matching patterns is the [`regexp_dcg`](file:///home/doug/code/regexp/regexp_dcg.pl) module.

### Quick Usage Examples

#### 1. Direct & Embedded DCG Matching (`re_match//1-2`)
Use `re_match` non-terminals directly inside `phrase/2`, `phrase/3`, or embedded within custom DCG rules:

```prolog
?- use_module(regexp_dcg).
   true.

% Match prefix and capture substring
?- phrase(re_match("a*b", Match), "aaabc", Rest).
   Match = "aaab", Rest = "c"
;  false.

% Simple prefix matching (boolean / non-capturing)
?- phrase(re_match("[a-z]+"), "hello world", Rest).
   Rest = " world"
;  false.
```

#### 2. Group Extraction (`re_match_groups//3` & `re_match_named//3`)
Extract numbered or named capturing groups:

```prolog
% Numbered capturing groups
?- phrase(re_match_groups("(\\d+)-(\\w+)", Match, Groups), "123-abc").
   Match = "123-abc", Groups = ["123", "abc"]
;  false.

% Named capturing groups
?- phrase(re_match_named("(?P<year>\\d{4})-(?P<month>\\d{2})", Match, Named), "2026-08").
   Match = "2026-08", Named = [year-"2026", month-"08"]
;  false.
```

#### 3. Pre-Compiling Reusable Patterns (`re_compile/2`)
For maximum efficiency when evaluating the same pattern against many inputs, pre-compile the pattern into a reusable goal:

```prolog
?- re_compile("[0-9]+", Compiled),
   phrase(re_match(Compiled, Digits), "12345extra", Rest).
   Compiled = compiled(call(regexp_dcg:dcg_concat([call(regexp_dcg:dcg_plus(call(regexp_dcg:dcg_class([range(48,57)]))))])), 0),
   Digits = "12345",
   Rest = "extra"
;  false.
```

---

## Library Architecture & Internal Modules

The library is structured into modular layers:

- **[`regexp_dcg.pl`](file:///home/doug/code/regexp/regexp_dcg.pl)** (Primary User Interface):
  Exposes user-facing DCG matching non-terminals (`re_match//1-2`, `re_match_groups//3`, `re_match_named//3`), group resolution (`re_group/3`), compilation (`re_compile/2`), and dynamic compilation caching.

- **[`regexp_ast.pl`](file:///home/doug/code/regexp/regexp_ast.pl)** (Parser & Tokenizer):
  Parses raw regular expression character lists into an Abstract Syntax Tree (AST) representation (`lit/1`, `class/1`, `group/1`, `star/1`, etc.). Implements tokenizers (`re_token//1`) and POSIX class parsing.

- **[`ast_dcg.pl`](file:///home/doug/code/regexp/ast_dcg.pl)** (DCG Code Generator):
  Transforms parsed AST terms into pure ISO Prolog DCG matching goals constructed from pure combinators (`dcg_lit`, `dcg_concat`, `dcg_or`, `dcg_star`, etc.).

- **[`regexp_compile_dfa.pl`](file:///home/doug/code/regexp/regexp_compile_dfa.pl)** (Experimental DFA Engine):
  An experimental NFA/DFA engine for benchmarking and comparing performance against the primary DCG engine.

---

## Multilingual & International Character Support

In ISO Prolog systems treating `double_quotes` as character lists (`chars`), strings represent sequences of native character code points. This library supports international character matching out of the box:

- **Exact Literals**: Accented Latin (`"café"`), Greek (`"αβγ"`), Chinese Hanzi (`"你好"`), Emojis (`"🚀😀"`), and Klingon script (`""` PUA / `"Qapla'"`).
- **Wildcard `.`**: Correctly matches 1 Unicode character (code point).
- **Character Classes & Ranges**: `[caféñ]` or `[α-ω]` match by Unicode code points.

> [!NOTE]
> **Case-Insensitivity Limitation (`(?i)`)**: Inline flag `(?i)` case folding is currently scoped to ASCII characters (`'A'-'Z'` $\leftrightarrow$ `'a'-'z'`). Non-ASCII international uppercase/lowercase foldings (e.g. `'É'` $\leftrightarrow$ `'é'`) are not automatically folded by `(?i)`.

- **Multilingual Example Script**: See [`examples/international/multilingual_matching.pl`](file:///home/doug/code/regexp/examples/international/multilingual_matching.pl).

---

## TOML Light Parser Example (`examples/toml/`)

The repository includes a complete **TOML Light Parser Example** under [`examples/toml/`](file:///home/doug/code/regexp/examples/toml/), demonstrating how `regexp_dcg` functions as a clean tokenizer combined with Prolog DCG grammars to parse configuration files into structured AST terms.

### Features Supported

- **Keys & Values**: `title = "My App"`, `count = 42`, `debug = true`
- **Arrays**: `ports = [8000, 8001, 8002]`, `names = ["a", "b", "c"]`
- **Tables**: `[server]` (headers and scope management)
- **Dotted Keys**: `database.host = "db.local"`, `database.port = 5432`
- **Inline Tables**: `owner = { name = "Doug", email = "doug@example.com" }`
- **Comments**: `# This is a comment`

### Demonstration Highlights

1. **Regex Tokenizer ([`examples/toml/toml_tokenizer.pl`](file:///home/doug/code/regexp/examples/toml/toml_tokenizer.pl))**:
   Demonstrates `regexp_dcg` features:
   - **Bare Keys**: `[A-Za-z0-9_-]+`
   - **Quoted Strings**: `"([^"\\]|\\.)*"`
   - **Numbers**: Integers & Floats (`-?[0-9]+(\.[0-9]+)?`)
   - **Booleans**: `true|false`
   - **Comments**: `#.*$`
   - **Quantifiers & Alternation**: Greedy/non-greedy quantifiers, character classes, whitespace skipping.
2. **DCG Grammar & AST Builder ([`examples/toml/toml_parser.pl`](file:///home/doug/code/regexp/examples/toml/toml_parser.pl))**:
   Recursive DCG rules building AST terms (`toml([kv(...), table(...), comment(...)])`) handling multi-line files and nested table scopes.
3. **Sample File & Runner ([`examples/toml/sample.toml`](file:///home/doug/code/regexp/examples/toml/sample.toml) & [`examples/toml/parse_sample.pl`](file:///home/doug/code/regexp/examples/toml/parse_sample.pl))**:
   Execute the TOML parser pipeline inside the `examples/toml` directory:
   ```bash
   cd examples/toml
   scryer-prolog parse_sample.pl -g main
   ```
   (or: `nice scryer-safe parse_sample.pl -g main`)

## Documentation & Test Suite

- **Detailed Documentation**: See [`docs/regexp_intro.md`](file:///home/doug/code/regexp/docs/regexp_intro.md) for full feature documentation and expected Scryer Prolog REPL outputs for all supported regular expression constructs.
- **Unit Tests**:
  - [`tests/test_regexp_dcg.pl`](file:///home/doug/code/regexp/tests/test_regexp_dcg.pl) — Core DCG engine matching tests.
  - [`tests/test_international.pl`](file:///home/doug/code/regexp/tests/test_international.pl) — Multilingual character tests (French, Greek, Chinese, Emoji, Klingon).
  - [`tests/test_regexp_ast.pl`](file:///home/doug/code/regexp/tests/test_regexp_ast.pl) — Regex parser and AST construction tests.
  - [`tests/test_ast_dcg.pl`](file:///home/doug/code/regexp/tests/test_ast_dcg.pl) — AST-to-DCG code generator tests.
  - [`tests/test_re_token.pl`](file:///home/doug/code/regexp/tests/test_re_token.pl) — Regex tokenization (`re_token//1`), metacharacter, and character class tests.
  - [`tests/test_exports_match.pl`](file:///home/doug/code/regexp/tests/test_exports_match.pl) — Module export interface consistency tests.

Run the test suite with:
```bash
make test
```

---

## Python Specification & Inspiration

The regular expression syntax and semantics supported by this library are inspired by **Python 3.14 regular expressions (`re`)**:

- [Python 3.14 Documentation for `re`](https://docs.python.org/3/library/re.html)
- [Python Source for `re`](https://github.com/python/cpython/tree/3.14/Lib/re)
- [Python Unit Tests for `re`](https://github.com/python/cpython/blob/3.14/Lib/test/test_re.py)
