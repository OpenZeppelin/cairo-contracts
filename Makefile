# Default paths (can be overridden via command-line args)
BENCHMARK_SCRIPT ?= scripts/benchmarking/benchmark.py
DIFF_SCRIPT ?= scripts/benchmarking/benchmark_diff.py
PREVIOUS_JSON ?= benches/contract_sizes.json
TARGET_DIR ?= target/release

# Run benchmark diff (normal output)
diff:
	python3 $(DIFF_SCRIPT) $(BENCHMARK_SCRIPT) $(PREVIOUS_JSON) --dir $(TARGET_DIR)

# Run benchmark diff with Markdown output
diff-md:
	python3 $(DIFF_SCRIPT) $(BENCHMARK_SCRIPT) $(PREVIOUS_JSON) --dir $(TARGET_DIR) --markdown
