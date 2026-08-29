NAME = regexp_dcg
VERSION = 0.1.2.dev1

export PROLOG_ENGINE ?= scryer
SCRYER ?= scryer-safe
PROLOG_AGENT ?= prolog-agent

.PHONY: all test test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_regexp_tree test_si test_time test_re_token test_international test_toml docs html llms packages package_bakage package_swi clean

all: test docs

# ==============================================================================
# Testing Targets (Executed via scryer-safe safety runner)
# ==============================================================================

test: test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_regexp_tree test_si test_time test_re_token test_international test_toml

test_curr_pred:
	@echo "=== Running test_curr_pred.pl ==="
	$(SCRYER) -g test_mod:main tests/scryer/test_curr_pred.pl
	@echo ""

test_exports_match:
	@echo "=== Running test_exports_match.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_exports_match.pl
	@echo ""

test_format:
	@echo "=== Running test_format.pl ==="
	$(SCRYER) -g main tests/portable/test_format.pl
	@echo ""

test_logs:
	@echo "=== Running test_logs.pl ==="
	$(SCRYER) -g test_logs:main tests/scryer/test_logs.pl
	@echo ""

test_regexp_ast:
	@echo "=== Running test_regexp_ast.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_regexp_ast.pl
	@echo ""

test_regexp_dcg:
	@echo "=== Running test_regexp_dcg.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_regexp_dcg.pl
	@echo ""

test_regexp_compile_dfa:
	@echo "=== Running test_regexp_compile_dfa.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_regexp_compile_dfa.pl
	@echo ""

test_regexp_tree:
	@echo "=== Running test_regexp_tree.pl ==="
	$(SCRYER) -g main -g halt tests/scryer/test_regexp_tree.pl
	@echo ""

test_si:
	@echo "=== Running test_si.pl ==="
	$(SCRYER) -g main tests/portable/test_si.pl
	@echo ""

test_time:
	@echo "=== Running test_time.pl ==="
	$(SCRYER) -g main tests/scryer/test_time.pl
	@echo ""

test_re_token:
	@echo "=== Running test_re_token.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_re_token.pl
	@echo ""

test_international:
	@echo "=== Running test_international.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_international.pl
	@echo ""

test_toml:
	@echo "=== Running test_toml.pl ==="
	$(SCRYER) -g run_tests -g halt tests/scryer/test_toml.pl
	@echo ""

# ==============================================================================
# Documentation Generation Targets
# ==============================================================================

docs: llms
	@echo "=== Generating docs/usage.md ==="
	$(SCRYER) -g main -g halt generate_intro_md.pl
	@echo "Docs successfully updated."
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
	pandoc -s --metadata title="Regexp DCG Usage Guide" --metadata description="Pure ISO Scryer Prolog regular expression engine user guide and pattern reference" --metadata keywords="prolog,scryer-prolog,regex,dcg,dfa,iso-prolog" -c "https://cdn.jsdelivr.net/npm/water.css@2/out/water.css" docs/usage.md -o docs/usage.html
	pandoc -s --metadata title="Regexp DCG Library" --metadata description="Pure ISO Scryer Prolog regular expression engine providing DCG non-terminal and direct list matching" --metadata keywords="prolog,scryer-prolog,regex,dcg,dfa,iso-prolog,bakage" -c "https://cdn.jsdelivr.net/npm/water.css@2/out/water.css" README.md -o readme.html
	@echo "HTML files successfully generated (docs/usage.html, readme.html)."
	@echo ""

# ==============================================================================
# Packaging Targets (Prolog Agent Toolkit Standards)
# ==============================================================================

packages: test docs package_bakage package_swi

package_bakage:
	@echo "=== Building Scryer bakage package ==="
	$(PROLOG_AGENT) pack --engine scryer

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
