#!/bin/bash
# Run benchmark comparison between current branch and specified branch
# with full parsing and visualization support
#
# Usage: ./run_comparison_with.sh [branch_name] [benchmark_type]
#   branch_name: Branch to compare against (default: main)
#   benchmark_type: Type of benchmark to run (default: bench_engine)

set -e  # Exit on error

# Parse command line arguments
TARGET_BRANCH="${1:-main}"
BENCHMARK_TYPE="${2:-bench_engine}"

echo "====================================================================="
echo "CURRENT BRANCH vs $TARGET_BRANCH BENCHMARK COMPARISON"
echo "Benchmark Type: $BENCHMARK_TYPE"
echo "====================================================================="
echo ""

# Validate that the target branch exists
if ! git rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
    echo "Error: Branch '$TARGET_BRANCH' does not exist."
    echo "Available branches:"
    git branch -a | sed 's/^/  /'
    exit 1
fi

# Save current branch/commit
CURRENT_REF=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse HEAD)

# Determine if we're on a branch or detached HEAD
if [ "$CURRENT_REF" = "HEAD" ]; then
    CURRENT_BRANCH="$CURRENT_COMMIT"
    echo "Current commit (detached HEAD): $CURRENT_BRANCH"
else
    CURRENT_BRANCH="$CURRENT_REF"
    echo "Current branch: $CURRENT_BRANCH"
fi

if [ "$CURRENT_BRANCH" = "$TARGET_BRANCH" ]; then
    echo "Error: Cannot compare branch with itself ('$CURRENT_BRANCH')"
    exit 1
fi

echo "Target branch: $TARGET_BRANCH"
echo ""

# Create results directory if it doesn't exist
mkdir -p benchmarks/results

# Set output file names based on benchmark type and target branch
# Sanitize branch names for file names (replace / with _)
SAFE_CURRENT_BRANCH=$(echo "$CURRENT_BRANCH" | sed 's/\//_/g')
SAFE_TARGET_BRANCH=$(echo "$TARGET_BRANCH" | sed 's/\//_/g')

CURRENT_RESULTS="benchmarks/results/${SAFE_CURRENT_BRANCH}_results.json"
TARGET_RESULTS="benchmarks/results/${SAFE_TARGET_BRANCH}_results.json"
COMPARISON_FILE="benchmarks/results/${SAFE_CURRENT_BRANCH}_vs_${SAFE_TARGET_BRANCH}_comparison.json"
OUTPUT_PREFIX="${SAFE_CURRENT_BRANCH}_vs_${SAFE_TARGET_BRANCH}_"

# Function to run benchmarks with parsing
run_and_parse_benchmarks() {
    local branch=$1
    local output_json=$2
    local output_txt="${output_json%.json}_output.txt"

    echo "Running benchmarks on branch: $branch..."
    echo "-----------------------------------------"

    # Run Mojo benchmarks and parse output
    mojo run -I src "benchmarks/${BENCHMARK_TYPE}.mojo" | tee "$output_txt" | python3 benchmarks/parse_mojo_output.py "$output_json"

    if [ -f "$output_json" ]; then
        echo "✓ Results saved to $output_json"

        # Show engine usage summary if available
        if grep -q "\[ENGINE\]" "$output_txt" 2>/dev/null; then
            echo ""
            echo "Engine Usage Summary for $branch:"
            echo "=============================="
            echo "DFA Engine: $(grep -c "Engine: DFA" "$output_txt" 2>/dev/null || echo 0) patterns"
            echo "NFA Engine: $(grep -c "Engine: NFA" "$output_txt" 2>/dev/null || echo 0) patterns"
            echo "SIMPLE Complexity: $(grep -c "Complexity: SIMPLE" "$output_txt" 2>/dev/null || echo 0) patterns"
            echo "MEDIUM Complexity: $(grep -c "Complexity: MEDIUM" "$output_txt" 2>/dev/null || echo 0) patterns"
            echo "COMPLEX Complexity: $(grep -c "Complexity: COMPLEX" "$output_txt" 2>/dev/null || echo 0) patterns"
        fi
    else
        echo "✗ Failed to generate results for $branch branch"
        exit 1
    fi
}

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Warning: You have uncommitted changes. These will not be included in the benchmark."
    echo "Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Step 1: Run benchmarks on current branch
echo "Step 1: Running benchmarks on current branch ($CURRENT_BRANCH)..."
run_and_parse_benchmarks "$CURRENT_BRANCH" "$CURRENT_RESULTS"
echo ""

# Step 2: Switch to target branch
echo "Step 2: Switching to $TARGET_BRANCH branch..."
echo "-----------------------------------------"
git checkout "$TARGET_BRANCH"
echo ""

# Step 3: Run benchmarks on target branch
echo "Step 3: Running benchmarks on $TARGET_BRANCH branch..."
run_and_parse_benchmarks "$TARGET_BRANCH" "$TARGET_RESULTS"
echo ""

# Step 4: Switch back to original branch
echo "Step 4: Switching back to $CURRENT_BRANCH..."
echo "-----------------------------------------"
git checkout "$CURRENT_BRANCH"
echo ""

# Step 5: Compare results
echo "Step 5: Comparing benchmark results..."
echo "--------------------------------------"
python3 benchmarks/compare_benchmarks.py "$TARGET_RESULTS" "$CURRENT_RESULTS" "$COMPARISON_FILE"

# Show engine usage comparison if engine data is available
CURRENT_OUTPUT="benchmarks/results/${SAFE_CURRENT_BRANCH}_results_output.txt"
TARGET_OUTPUT="benchmarks/results/${SAFE_TARGET_BRANCH}_results_output.txt"
if [[ -f "$CURRENT_OUTPUT" && -f "$TARGET_OUTPUT" ]] && grep -q "\[ENGINE\]" "$CURRENT_OUTPUT" 2>/dev/null; then
    echo ""
    echo "Engine Usage Comparison:"
    echo "========================"
    echo "Branch: $CURRENT_BRANCH"
    echo "  DFA Engine: $(grep -c "Engine: DFA" "$CURRENT_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "  NFA Engine: $(grep -c "Engine: NFA" "$CURRENT_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "Branch: $TARGET_BRANCH"
    echo "  DFA Engine: $(grep -c "Engine: DFA" "$TARGET_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "  NFA Engine: $(grep -c "Engine: NFA" "$TARGET_OUTPUT" 2>/dev/null || echo 0) patterns"
fi
echo ""

# Step 6: Generate visualizations (if matplotlib is available)
echo "Step 6: Generating visualizations..."
echo "------------------------------------"
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 benchmarks/visualize_results.py "$COMPARISON_FILE" "benchmarks/results/${OUTPUT_PREFIX}"
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
echo "  - ${SAFE_CURRENT_BRANCH}_results.json              : Current branch ($CURRENT_BRANCH) benchmark data"
echo "  - ${SAFE_TARGET_BRANCH}_results.json               : Target branch ($TARGET_BRANCH) benchmark data"
echo "  - ${SAFE_CURRENT_BRANCH}_vs_${SAFE_TARGET_BRANCH}_comparison.json : Detailed comparison data"
if python3 -c "import matplotlib" 2>/dev/null; then
    echo "  - ${OUTPUT_PREFIX}speedup_chart.png              : Bar chart of speedup factors"
    echo "  - ${OUTPUT_PREFIX}time_comparison.png            : Side-by-side time comparison"
    echo "  - ${OUTPUT_PREFIX}category_analysis.png          : Performance by regex category"
fi
echo ""
echo "NOTE: In the comparison results:"
echo "  - Speedup > 1.0 means current branch ($CURRENT_BRANCH) is faster than $TARGET_BRANCH"
echo "  - Speedup < 1.0 means $TARGET_BRANCH is faster than current branch"
echo ""
