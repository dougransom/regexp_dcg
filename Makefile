.PHONY: test test_ast_dcg test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_si test_time test_re_token test_international

test: test_ast_dcg test_curr_pred test_exports_match test_format test_logs test_regexp_ast test_regexp_dcg test_regexp_compile_dfa test_si test_time test_re_token test_international

test_ast_dcg:
	@echo "=== Running test_ast_dcg.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_ast_dcg.pl
	@echo ""

test_curr_pred:
	@echo "=== Running test_curr_pred.pl ==="
	nice scryer-safe -g test_mod:main tests/test_curr_pred.pl
	@echo ""

test_format:
	@echo "=== Running test_format.pl ==="
	nice scryer-safe -g main tests/test_format.pl
	@echo ""

test_logs:
	@echo "=== Running test_logs.pl ==="
	nice scryer-safe -g test_logs:main tests/test_logs.pl
	@echo ""

test_regexp_ast:
	@echo "=== Running test_regexp_ast.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_regexp_ast.pl
	@echo ""

test_regexp_dcg:
	@echo "=== Running test_regexp_dcg.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_regexp_dcg.pl
	@echo ""

test_regexp_compile_dfa:
	@echo "=== Running test_regexp_compile_dfa.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_regexp_compile_dfa.pl
	@echo ""

test_exports_match:
	@echo "=== Running test_exports_match.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_exports_match.pl
	@echo ""

test_si:
	@echo "=== Running test_si.pl ==="
	nice scryer-safe -g main tests/test_si.pl
	@echo ""

test_time:
	@echo "=== Running test_time.pl ==="
	nice scryer-safe -g main tests/test_time.pl
	@echo ""

test_re_token:
	@echo "=== Running test_re_token.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_re_token.pl
	@echo ""

test_international:
	@echo "=== Running test_international.pl ==="
	nice scryer-safe -g run_tests -g halt tests/test_international.pl
	@echo ""
