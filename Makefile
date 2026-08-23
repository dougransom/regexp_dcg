SCRYER ?= scryer-prolog

.PHONY: test test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_si test_time test_re_token test_international test_toml docs

test: test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_si test_time test_re_token test_international test_toml

test_toml:
	@echo "=== Running test_toml.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_toml.pl
	@echo ""

docs:
	@echo "=== Generating docs/regexp_intro.md ==="
	$(SCRYER) -g main -g halt generate_intro_md.pl
	@echo "Docs successfully updated."
	@echo ""

test_curr_pred:
	@echo "=== Running test_curr_pred.pl ==="
	$(SCRYER) -g test_mod:main tests/test_curr_pred.pl
	@echo ""

test_format:
	@echo "=== Running test_format.pl ==="
	$(SCRYER) -g main tests/test_format.pl
	@echo ""

test_logs:
	@echo "=== Running test_logs.pl ==="
	$(SCRYER) -g test_logs:main tests/test_logs.pl
	@echo ""

test_regexp_ast:
	@echo "=== Running test_regexp_ast.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_regexp_ast.pl
	@echo ""

test_regexp_dcg:
	@echo "=== Running test_regexp_dcg.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_regexp_dcg.pl
	@echo ""

test_regexp_compile_dfa:
	@echo "=== Running test_regexp_compile_dfa.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_regexp_compile_dfa.pl
	@echo ""

test_exports_match:
	@echo "=== Running test_exports_match.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_exports_match.pl
	@echo ""

test_si:
	@echo "=== Running test_si.pl ==="
	$(SCRYER) -g main tests/test_si.pl
	@echo ""

test_time:
	@echo "=== Running test_time.pl ==="
	$(SCRYER) -g main tests/test_time.pl
	@echo ""

test_re_token:
	@echo "=== Running test_re_token.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_re_token.pl
	@echo ""

test_international:
	@echo "=== Running test_international.pl ==="
	$(SCRYER) -g run_tests -g halt tests/test_international.pl
	@echo ""
