#!/bin/bash
# Run benchmark comparison between current branch and main branch
# with full parsing and visualization support

set -e  # Exit on error

# Default benchmark type
BENCHMARK_TYPE="bench_engine"

echo "====================================================================="
echo "CURRENT BRANCH vs MAIN BRANCH BENCHMARK COMPARISON"
echo "Benchmark Type: $BENCHMARK_TYPE"
echo "====================================================================="
echo ""

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"
echo ""

# Create results directory if it doesn't exist
mkdir -p benchmarks/results

# Set output file names based on benchmark type
CURRENT_RESULTS="benchmarks/results/current_branch_results.json"
MAIN_RESULTS="benchmarks/results/main_branch_results.json"
OUTPUT_PREFIX=""

# Function to run benchmarks with parsing
run_and_parse_benchmarks() {
    local branch=$1
    local output_json=$2
    local output_txt="${output_json%.json}_output.txt"

    echo "Running benchmarks on branch: $branch..."
    echo "-----------------------------------------"

    # Run Mojo benchmarks and parse output
    mojo run "benchmarks/${BENCHMARK_TYPE}.mojo" | tee "$output_txt" | python3 benchmarks/parse_mojo_output.py "$output_json"

    if [ -f "$output_json" ]; then
        echo "✓ Results saved to $output_json"
    else
        echo "✗ Failed to generate results for $branch branch"
        exit 1
    fi
}

# Step 1: Run benchmarks on current branch
echo "Step 1: Running benchmarks on current branch ($CURRENT_BRANCH)..."
run_and_parse_benchmarks "$CURRENT_BRANCH" "$CURRENT_RESULTS"
echo ""

# Step 2: Switch to main branch
echo "Step 2: Switching to main branch..."
echo "-----------------------------------------"
git checkout main
echo ""

# Step 3: Run benchmarks on main branch
echo "Step 3: Running benchmarks on main branch..."
run_and_parse_benchmarks "main" "$MAIN_RESULTS"
echo ""

# Step 4: Switch back to original branch
echo "Step 4: Switching back to $CURRENT_BRANCH..."
echo "-----------------------------------------"
git checkout "$CURRENT_BRANCH"
echo ""

# Step 5: Compare results
echo "Step 5: Comparing benchmark results..."
echo "--------------------------------------"
python3 benchmarks/compare_benchmarks.py "$MAIN_RESULTS" "$CURRENT_RESULTS" "benchmarks/results/${OUTPUT_PREFIX}branch_comparison.json"
echo ""

# Step 6: Generate visualizations (if matplotlib is available)
echo "Step 6: Generating visualizations..."
echo "------------------------------------"
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 benchmarks/visualize_results.py "benchmarks/results/${OUTPUT_PREFIX}branch_comparison.json" "${OUTPUT_PREFIX}branch_"
    echo ""
    echo "Visualizations created successfully!"
else
    echo "Warning: matplotlib not installed. Skipping visualizations."
    echo "Install with: pip install matplotlib"
fi

echo ""
echo "====================================================================="
echo "BRANCH COMPARISON COMPLETE!"
echo "====================================================================="
echo ""
echo "Results saved in benchmarks/results/:"
echo "  - ${OUTPUT_PREFIX}current_branch_results.json  : Current branch ($CURRENT_BRANCH) benchmark data"
echo "  - ${OUTPUT_PREFIX}main_branch_results.json      : Main branch benchmark data"
echo "  - ${OUTPUT_PREFIX}branch_comparison.json        : Detailed comparison data"
if python3 -c "import matplotlib" 2>/dev/null; then
    echo "  - ${OUTPUT_PREFIX}branch_speedup_chart.png     : Bar chart of speedup factors"
    echo "  - ${OUTPUT_PREFIX}branch_time_comparison.png   : Side-by-side time comparison"
    echo "  - ${OUTPUT_PREFIX}branch_category_analysis.png : Performance by regex category"
fi
echo ""
echo "NOTE: In the comparison results:"
echo "  - Speedup > 1.0 means current branch ($CURRENT_BRANCH) is faster than main"
echo "  - Speedup < 1.0 means main branch is faster than current branch"
echo ""
