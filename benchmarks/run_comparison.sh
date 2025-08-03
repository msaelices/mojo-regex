#!/bin/bash
# Run complete benchmark comparison between Mojo and Python regex implementations

set -e  # Exit on error

echo "====================================================================="
echo "MOJO vs PYTHON REGEX BENCHMARK COMPARISON"
echo "====================================================================="
echo ""

# Create results directory if it doesn't exist
mkdir -p benchmarks/results

# Run Python benchmarks
echo "Step 1: Running Python regex benchmarks..."
echo "-----------------------------------------"
python3 benchmarks/bench_engine.py
echo ""

# Run Mojo benchmarks and parse output
echo "Step 2: Running Mojo regex benchmarks..."
echo "----------------------------------------"
# Capture Mojo output and parse it
mojo run benchmarks/bench_engine.mojo | tee benchmarks/results/mojo_output.txt | python3 benchmarks/parse_mojo_output.py
echo ""

# Compare results
echo "Step 3: Comparing benchmark results..."
echo "--------------------------------------"
python3 benchmarks/compare_benchmarks.py
echo ""

# Generate visualizations (if matplotlib is available)
echo "Step 4: Generating visualizations..."
echo "------------------------------------"
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 benchmarks/visualize_results.py
    echo ""
    echo "Visualizations created successfully!"
else
    echo "Warning: matplotlib not installed. Skipping visualizations."
    echo "Install with: pip install matplotlib"
fi

echo ""
echo "====================================================================="
echo "BENCHMARK COMPARISON COMPLETE!"
echo "====================================================================="
echo ""
echo "Results saved in benchmarks/results/:"
echo "  - mojo_results.json    : Raw Mojo benchmark data"
echo "  - python_results.json  : Raw Python benchmark data"
echo "  - comparison.json      : Detailed comparison data"
if python3 -c "import matplotlib" 2>/dev/null; then
    echo "  - speedup_chart.png    : Bar chart of speedup factors"
    echo "  - time_comparison.png  : Side-by-side time comparison"
    echo "  - category_analysis.png: Performance by regex category"
fi
echo ""
