# Regular Expression Engine for Scryer Prolog and ISO Prolog Systems (`regexp_dcg`)

A pure, ISO-compliant regular expression engine providing both **Definite Clause Grammar (DCG) non-terminal** and **direct character list (`chars`) matching interfaces** for [Scryer Prolog](https://github.com/mthom/scryer-prolog) and other ISO-compliant Prolog implementations.

### Categories & Classifiers

- **Topic**: `Software Development :: Libraries :: Prolog Modules`, `Text Processing :: Pattern Matching :: Regular Expressions`, `Compilers/Interpreters :: Definite Clause Grammars (DCG)`
- **Programming Language**: `Prolog :: ISO-Compliant`
- **Target Systems**: `Scryer Prolog`, `Trealla Prolog`, `Tau Prolog`, `GNU Prolog`
- **License**: `Unlicense (Public Domain)`

### Project Goals

The primary goals of this project are:

1. **ISO-Compliant & Pure**: Provide a portable, pure, ISO-compliant Regular Expression (`REGEXP`) matching library for Scryer Prolog and other ISO Prolog systems (such as Trealla Prolog, Tau Prolog, GNU Prolog, Ciao, etc.) without relying on system-dependent C primitives or foreign function interfaces.
2. **Dual Matching Interfaces**: Support both:
   - **DCG Non-Terminal Interface**: Pure DCG non-terminal grammars (`phrase(re_match(Pattern, Match), Input)`) for seamlessly embedding regular expression rules inside Prolog DCG parsing logic.
   - **Direct Character List Interface**: Standard 2/3/4/5-argument list matching predicates (`re_match(Pattern, Input)`, `re_match(Pattern, Input, Rest)`, `re_match_groups/4-5`, `re_match_named/4-5`) for direct string matching without needing `phrase/2-3` wrappers.
3. **Engine Parity & Choice**: Provide multiple, 1:1 API-compatible matching engines:
   - **DCG Backtracking Engine** (`regexp_dcg.pl`): Full-featured regex parser with group extractions, lookaheads, and inline flags.
   - **Rational Tree Automaton Engine** (`regexp_tree.pl`): Fast, pure `if_/3`-driven cyclic term finite state automaton matching.
   - **DFA Engine** (`src/regexp_compile_dfa.pl`): Deterministic finite automaton execution.

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

   % DCG Interface
   ?- phrase(re_match("[a-z]+", Match), "hello").

   % Direct Characters Interface
   ?- re_match("[a-z]+", "hello").
   ```

### Option 2: Without Bakage (Direct Import / Git Clone)

1. **Clone or Download the Repository**:
   ```bash
   git clone https://github.com/dougransom/regexp_dcg.git
   ```

2. **Direct Import via `use_module/1`**:
   Import `regexp_dcg.pl` (or `regexp_tree.pl`) using its relative path:

   ```prolog
   :- use_module('path/to/regexp_dcg/regexp_dcg').

   % Direct Character Matching
   ?- re_match("[a-z]+", "hello").

   % DCG Non-Terminal Matching
   ?- phrase(re_match("[a-z]+", Match), "hello").
   ```

   > [!NOTE]
   > If your Prolog system provides this package out-of-the-box (or on its library path), you can import it directly:
   > ```prolog
   > :- use_module(library(regexp_dcg)).  % or :- use_module(regexp_dcg).
   > ```

---

## Primary Interface (`regexp_dcg` & `regexp_tree`)

The main entry point for matching patterns is either the [`regexp_dcg`](regexp_dcg.pl) or [`regexp_tree`](regexp_tree.pl) module. For a comprehensive walkthrough of supported pattern constructs and REPL output examples, see the [`docs/usage.md`](docs/usage.md) guide.

### Quick Usage Examples

#### 1. Direct Character Matching (`re_match/2-3`)
Match character lists directly without needing DCG `phrase/2-3` wrappers:

```prolog
?- use_module(regexp_dcg). % or :- use_module(regexp_tree).
   true.

% Direct full match (anchored)
?- re_match("a*b", "aaab").
   true.

% Direct match returning unparsed remainder
?- re_match("a*b", "aaabc", Rest).
   Rest = "c"
;  false.
```

#### 2. DCG Non-Terminal Matching (`re_match//1-2`)
Use `re_match` non-terminals directly inside `phrase/2`, `phrase/3`, or embedded within custom DCG rules:

```prolog
% Match prefix and capture substring inside DCG
?- phrase(re_match("a*b", Match), "aaabc", Rest).
   Match = "aaab", Rest = "c"
;  false.

% Simple prefix matching (boolean / non-capturing)
?- phrase(re_match("[a-z]+"), "hello world", Rest).
   Rest = " world"
;  false.
```

#### 3. Group Extraction (`re_match_groups` & `re_match_named`)
Extract numbered or named capturing groups via direct predicates or DCG non-terminals:

```prolog
% Direct group extraction
?- re_match_groups("(\\d+)-(\\w+)", "123-abc", Match, Groups).
   Match = "123-abc", Groups = ["123", "abc"]
;  false.

% Named capturing groups inside DCG
?- phrase(re_match_named("(?P<year>\\d{4})-(?P<month>\\d{2})", Match, Named), "2026-08").
   Match = "2026-08", Named = [year-"2026", month-"08"]
;  false.
```

#### 4. Pre-Compiling Reusable Patterns (`re_compile/2`)
For maximum efficiency when evaluating the same pattern against many inputs, pre-compile the pattern into a reusable structure:

```prolog
?- re_compile("[0-9]+", Compiled),
   re_match(Compiled, "12345extra", Rest).
   Compiled = compiled(call(regexp_dcg:dcg_concat([call(regexp_dcg:dcg_plus(call(regexp_dcg:dcg_class([range(48,57)]))))])), 0),
   Rest = "extra"
;  false.
```

---

## Library Architecture & Internal Modules

The library is structured into modular layers:

- **[`regexp_dcg.pl`](regexp_dcg.pl)** (DCG Backtracking Engine):
  Full-featured DCG backtracking regular expression engine with capturing groups, lookaheads, and inline flags.

- **[`regexp_tree.pl`](regexp_tree.pl)** (Rational Tree Automaton Engine):
  Fast, pure `if_/3`-driven cyclic term finite state automaton matching.

- **[`src/regexp_ast.pl`](src/regexp_ast.pl)** (Parser & Tokenizer):
  Parses raw regular expression character lists into an Abstract Syntax Tree (AST) representation (`lit/1`, `class/1`, `group/1`, `star/1`, etc.). Implements tokenizers (`re_token//1`) and POSIX class parsing.

- **[`src/regexp_compile_dfa.pl`](src/regexp_compile_dfa.pl)** (Experimental DFA Engine):
  An experimental NFA/DFA engine for benchmarking and comparing performance against the primary DCG and Tree engines.

---

## Multilingual & International Character Support

In ISO Prolog systems treating `double_quotes` as character lists (`chars`), strings represent sequences of native character code points. This library supports international character matching out of the box:

- **Exact Literals**: Accented Latin (`"café"`), Greek (`"αβγ"`), Chinese Hanzi (`"你好"`), Emojis (`"🚀😀"`), and Klingon script (`"Qapla'"` / PUA code points `"\uF8D5\uF8D4\uF8E1\uF8D5\uF8DF"`).
- **Wildcard `.`**: Correctly matches 1 Unicode character (code point).
- **Character Classes & Ranges**: `[caféñ]` or `[α-ω]` match by Unicode code points.

> [!NOTE]
> **Case-Insensitivity Limitation (`(?i)`)**: Inline flag `(?i)` case folding is currently scoped to ASCII characters (`'A'-'Z'` $\leftrightarrow$ `'a'-'z'`). Non-ASCII international uppercase/lowercase foldings (e.g. `'É'` $\leftrightarrow$ `'é'`) are not automatically folded by `(?i)`.

- **Multilingual Example Script**: See [`examples/international/multilingual_matching.pl`](examples/international/multilingual_matching.pl).

---

## TOML Light Parser Example (`examples/toml/`)

The repository includes a complete **TOML Light Parser Example** under [`examples/toml/`](examples/toml/), demonstrating how `regexp_dcg` functions as a clean tokenizer combined with Prolog DCG grammars to parse configuration files into structured AST terms.

### Features Supported

- **Keys & Values**: `title = "My App"`, `count = 42`, `debug = true`
- **Arrays**: `ports = [8000, 8001, 8002]`, `names = ["a", "b", "c"]`
- **Tables**: `[server]` (headers and scope management)
- **Dotted Keys**: `database.host = "db.local"`, `database.port = 5432`
- **Inline Tables**: `owner = { name = "Doug", email = "doug@example.com" }`
- **Comments**: `# This is a comment`

### Demonstration Highlights

1. **Regex Tokenizer ([`examples/toml/toml_tokenizer.pl`](examples/toml/toml_tokenizer.pl))**:
   Demonstrates `regexp_dcg` features:
   - **Bare Keys**: `[A-Za-z0-9_-]+`
   - **Quoted Strings**: `"([^"\\]|\\.)*"`
   - **Numbers**: Integers & Floats (`-?[0-9]+(\.[0-9]+)?`)
   - **Booleans**: `true|false`
   - **Comments**: `#.*$`
   - **Quantifiers & Alternation**: Greedy/non-greedy quantifiers, character classes, whitespace skipping.
2. **DCG Grammar & AST Builder ([`examples/toml/toml_parser.pl`](examples/toml/toml_parser.pl))**:
   Recursive DCG rules building AST terms (`toml([kv(...), table(...), comment(...)])`) handling multi-line files and nested table scopes.
3. **Sample File & Runner ([`examples/toml/sample.toml`](examples/toml/sample.toml) & [`examples/toml/parse_sample.pl`](examples/toml/parse_sample.pl))**:
   Execute the TOML parser pipeline inside the `examples/toml` directory:
   ```bash
   cd examples/toml
   scryer-prolog parse_sample.pl -g main
   ```
   (or: `nice scryer-safe parse_sample.pl -g main`)

## Documentation & Test Suite

- **Detailed Documentation**: See [`docs/usage.md`](docs/usage.md) for full feature documentation and expected Scryer Prolog REPL outputs for all supported regular expression constructs.
- **Unit Tests**:
  - [`tests/test_regexp_dcg.pl`](tests/test_regexp_dcg.pl) — Core DCG engine matching tests.
  - [`tests/test_regexp_tree.pl`](tests/test_regexp_tree.pl) — Rational Tree Automaton engine tests.
  - [`tests/test_international.pl`](tests/test_international.pl) — Multilingual character tests (French, Greek, Chinese, Emoji, Klingon).
  - [`tests/test_regexp_ast.pl`](tests/test_regexp_ast.pl) — Regex parser and AST construction tests.
  - [`tests/test_re_token.pl`](tests/test_re_token.pl) — Regex tokenization (`re_token//1`), metacharacter, and character class tests.
  - [`tests/test_exports_match.pl`](tests/test_exports_match.pl) — Module export interface consistency tests across all engine implementations.

- **Testing Requirements**:
  - **Bug Fixes**: Always add a test case reproducing the issue (which failed before the fix) when fixing any bug.
  - **New Interfaces**: Any new public interface, predicate, or feature addition must include dedicated unit tests.

Run the test suite with:
```bash
make test
```

---

## Future Directions & Vision

Drawing inspiration from finite state machine compilers like **[Ragel](https://www.colm.net/open-source/ragel/)** and Kleene algebra theory, Prolog is uniquely suited to evolve this regular expression engine beyond string matching into an algebraic reasoning and state machine synthesis tool:

1. **Algebraic Reasoning & Set Operations**:
   - **Intersection ($R_1 \cap R_2$) & Difference ($R_1 \setminus R_2$)**: Constructing product automata and minimal DFA complements to compute formal regular language intersections and set differences.
   - **Subsumption & Equivalence**: Proving whether $R_1 \subseteq R_2$ or $R_1 \equiv R_2$ via language emptiness checks ($L(R_1 \setminus R_2) = \emptyset$).

2. **Induction & Shortest Regular Expression Synthesis**:
   - Leveraging Prolog's natural bidirectionality to find the provably shortest regular expression matching a set of positive string examples while rejecting negative string examples.

3. **Brzozowski & Antimirov Derivatives**:
   - Utilizing regular expression derivatives ($\partial_a R$) to enable direct DFA generation, pattern canonicalization ($a(b|b) \rightarrow ab$), and algebraic expression simplification.

4. **The Ragel Connection (State Machine Compilation & Embedded Actions)**:
   - Inspired by **[Ragel State Machine Compiler](https://www.colm.net/open-source/ragel/)**, regular expressions can be treated as formal state machine compilation targets rather than purely interpreted string matchers.
   - Embedding arbitrary Prolog goals, semantic guards, and accumulator updates directly onto state transition edges ($S_i \to S_j$ with action goals), transforming the regular expression engine into a high-performance, compiled lexer/parser generator.

---

## Python Specification & Inspiration

The regular expression syntax and semantics supported by this library are inspired by **Python 3.14 regular expressions (`re`)**:

- [Python 3.14 Documentation for `re`](https://docs.python.org/3/library/re.html)
- [Python Source for `re`](https://github.com/python/cpython/tree/3.14/Lib/re)
- [Python Unit Tests for `re`](https://github.com/python/cpython/blob/3.14/Lib/test/test_re.py)

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "SoftwareSourceCode",
  "name": "regexp_dcg",
  "version": "0.1.1",
  "description": "A pure, ISO-compliant Definite Clause Grammar (DCG) regular expression engine designed for Scryer Prolog and other ISO-compliant Prolog implementations.",
  "programmingLanguage": {
    "@type": "ComputerLanguage",
    "name": "Prolog",
    "alternateName": "ISO Prolog"
  },
  "runtimePlatform": "Scryer Prolog",
  "codeRepository": "https://github.com/dougransom/regexp_dcg",
  "license": "https://unlicense.org",
  "author": {
    "@type": "Person",
    "name": "Doug Ransom"
  },
  "keywords": [
    "prolog",
    "scryer-prolog",
    "iso-prolog",
    "dcg",
    "regular-expressions",
    "regex",
    "parser"
  ]
}
</script>
