NAME = pure_regex
VERSION = 0.1.1.dev1

export PROLOG_ENGINE ?= scryer
PROLOG ?= $(PROLOG_ENGINE)-safe
SCRYER ?= $(PROLOG)
PROLOG_AGENT ?= prolog-agent

.PHONY: all test test_regexp test_curr_pred test_exports_match test_format test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_regexp_tree test_si test_time test_re_token test_international test_toml test_bidirectional test_expansion docs html llms tree_doc_examples packages package_engine package_bakage package_swi clean

all: test docs

# ==============================================================================
# Testing Targets (Executed via generic $(PROLOG) safety runner)
# ==============================================================================

test: test_regexp test_curr_pred test_exports_match test_format test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_regexp_tree test_si test_time test_re_token test_international test_toml test_bidirectional test_expansion

test_curr_pred:
	@echo "=== Running test_curr_pred.pl ==="
	$(PROLOG) -g test_mod:main tests/$(PROLOG_ENGINE)/test_curr_pred.pl
	@echo ""

test_exports_match:
	@echo "=== Running test_exports_match.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_exports_match.pl
	@echo ""

test_format:
	@echo "=== Running test_format.pl ==="
	$(PROLOG) -g main tests/portable/test_format.pl
	@echo ""

test_regexp_ast:
	@echo "=== Running test_regexp_ast.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_regexp_ast.pl
	@echo ""

test_regexp:
	@echo "=== Running test_regexp.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_regexp.pl
	@echo ""

test_regexp_dcg:
	@echo "=== Running test_regexp_dcg.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_regexp_dcg.pl
	@echo ""

test_regexp_compile_dfa:
	@echo "=== Running test_regexp_compile_dfa.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_regexp_compile_dfa.pl
	@echo ""

test_regexp_tree:
	@echo "=== Running test_regexp_tree.pl ==="
	$(PROLOG) -g main -g halt tests/$(PROLOG_ENGINE)/test_regexp_tree.pl
	@echo ""

test_si:
	@echo "=== Running test_si.pl ==="
	$(PROLOG) -g main tests/portable/test_si.pl
	@echo ""

test_time:
	@echo "=== Running test_time.pl ==="
	$(PROLOG) -g main tests/$(PROLOG_ENGINE)/test_time.pl
	@echo ""

test_re_token:
	@echo "=== Running test_re_token.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_re_token.pl
	@echo ""

test_international:
	@echo "=== Running test_international.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_international.pl
	@echo ""

test_toml:
	@echo "=== Running test_toml.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_toml.pl
	@echo ""

test_bidirectional:
	@echo "=== Running test_bidirectional.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_bidirectional.pl
	@echo ""

test_expansion:
	@echo "=== Running test_expansion.pl ==="
	$(PROLOG) -g run_tests -g halt tests/$(PROLOG_ENGINE)/test_expansion.pl
	@echo ""

# ==============================================================================
# Documentation Generation Targets
# ==============================================================================

docs: llms tree_doc_examples
	@echo "=== Generating docs/usage.md ==="
	$(PROLOG) -g main -g halt scripts/generate_intro_md.pl
	@echo "Docs successfully updated."
	@echo ""

tree_doc_examples:
	@echo "=== Generating Rational Tree Automata Doc Examples ==="
	$(PROLOG) -g main -g halt scripts/generate_tree_doc_examples.pl
	@echo ""

llms:
	@echo "=== Generating llms-full.txt ==="
	@cat llms.txt > llms-full.txt
	@echo "\n\n---\n\n# Full User Guide & Pattern Reference\n" >> llms-full.txt
	@cat docs/usage.md >> llms-full.txt
	@echo "\n\n---\n\n# Project README\n" >> llms-full.txt
	@cat README.md >> llms-full.txt
	@echo "llms-full.txt successfully generated."
	@echo ""

html: docs
	@echo "=== Generating HTML documentation ==="
	pandoc -s --metadata title="pure_regex Usage Guide" --metadata description="Pure ISO Scryer Prolog regular expression engine user guide and pattern reference" --metadata keywords="prolog,scryer-prolog,regex,dcg,dfa,iso-prolog,pure-prolog" -c "https://cdn.jsdelivr.net/npm/water.css@2/out/water.css" docs/usage.md -o docs/usage.html
	pandoc -s --metadata title="pure_regex Library" --metadata description="Pure ISO Scryer Prolog regular expression engine providing DCG non-terminal and direct list matching" --metadata keywords="prolog,scryer-prolog,regex,dcg,dfa,iso-prolog,bakage,pure-prolog" -c "https://cdn.jsdelivr.net/npm/water.css@2/out/water.css" README.md -o readme.html
	@echo "HTML files successfully generated (docs/usage.html, readme.html)."
	@echo ""

# ==============================================================================
# Packaging Targets (Prolog Agent Toolkit Standards)
# ==============================================================================

packages: test docs package_engine package_swi

package_engine:
	@echo "=== Building $(PROLOG_ENGINE) package ==="
	$(PROLOG_AGENT) pack --engine $(PROLOG_ENGINE)

package_bakage: package_engine

package_swi:
	@echo "=== Building SWI pack_install package ==="
	$(PROLOG_AGENT) pack --engine swi

# ==============================================================================
# Cleanup Target
# ==============================================================================

clean:
	@echo "=== Cleaning generated artifacts ==="
	rm -rf dist/ docs/usage.html readme.html llms-full.txt
	@echo "Cleanup complete."
