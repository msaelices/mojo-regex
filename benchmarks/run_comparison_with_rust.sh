#!/bin/bash
# Run complete benchmark comparison between Mojo and Rust regex implementations

set -e  # Exit on error

# Default benchmark type
BENCHMARK_TYPE="${1:-bench_engine}"

# Validate argument
if [[ "$BENCHMARK_TYPE" != "bench_engine" && "$BENCHMARK_TYPE" != "simd_focused_benchmark" ]]; then
    echo "Error: Invalid benchmark type '$BENCHMARK_TYPE'"
    echo "Usage: $0 [bench_engine|simd_focused_benchmark]"
    echo ""
    echo "Available benchmark types:"
    echo "  bench_engine           - General regex engine benchmarks (default)"
    echo "  simd_focused_benchmark - SIMD-focused NFA engine benchmarks"
    exit 1
fi

echo "======================================================================"
echo "MOJO vs RUST REGEX BENCHMARK COMPARISON"
echo "Benchmark Type: $BENCHMARK_TYPE"
echo "======================================================================"
echo ""

# Create results directory if it doesn't exist
mkdir -p benchmarks/results

# Set output file names based on benchmark type
if [[ "$BENCHMARK_TYPE" == "simd_focused_benchmark" ]]; then
    RUST_RESULTS="benchmarks/results/rust_simd_results.json"
    MOJO_RESULTS="benchmarks/results/mojo_simd_results.json"
    OUTPUT_PREFIX="rust_simd_"
else
    RUST_RESULTS="benchmarks/results/rust_results.json"
    MOJO_RESULTS="benchmarks/results/mojo_results.json"
    OUTPUT_PREFIX="rust_"
fi

# Check if Rust is installed
if ! command -v cargo >/dev/null 2>&1; then
    echo "Error: Rust/Cargo not found. Please install Rust from https://rustup.rs/"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "benchmarks/rust/Cargo.toml" ]]; then
    echo "Error: Rust benchmark project not found at benchmarks/rust/Cargo.toml"
    echo "Please ensure you're in the mojo-regex project root directory"
    exit 1
fi

# Run Rust benchmarks
echo "Step 1: Running Rust regex benchmarks..."
echo "-----------------------------------------"
cd benchmarks/rust

# Build in release mode with optimizations
echo "Building Rust benchmarks with maximum optimizations..."
export RUSTFLAGS="-C target-cpu=native"
cargo build --release --bin bench_engine

# Run the benchmark
echo "Executing Rust benchmarks..."
cargo run --release --bin bench_engine

# Return to project root
cd ../..

# Check if Rust results were generated
if [[ ! -f "$RUST_RESULTS" ]]; then
    echo "Error: Rust benchmark results not found at $RUST_RESULTS"
    exit 1
fi

echo ""

# Run Mojo benchmarks and parse output
echo "Step 2: Running Mojo regex benchmarks..."
echo "----------------------------------------"
# Capture Mojo output and parse it
mojo run -I src "benchmarks/${BENCHMARK_TYPE}.mojo" | tee "benchmarks/results/${OUTPUT_PREFIX}mojo_output.txt" | python3 benchmarks/parse_mojo_output.py "$MOJO_RESULTS"

# Show engine usage summary if available
MOJO_OUTPUT="benchmarks/results/${OUTPUT_PREFIX}mojo_output.txt"
if grep -q "\\[ENGINE\\]" "$MOJO_OUTPUT" 2>/dev/null; then
    echo ""
    echo "Mojo Engine Usage Summary:"
    echo "=========================="
    echo "DFA Engine: $(grep -c "Engine: DFA" "$MOJO_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "NFA Engine: $(grep -c "Engine: NFA" "$MOJO_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "SIMPLE Complexity: $(grep -c "Complexity: SIMPLE" "$MOJO_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "MEDIUM Complexity: $(grep -c "Complexity: MEDIUM" "$MOJO_OUTPUT" 2>/dev/null || echo 0) patterns"
    echo "COMPLEX Complexity: $(grep -c "Complexity: COMPLEX" "$MOJO_OUTPUT" 2>/dev/null || echo 0) patterns"
fi
echo ""

# Compare results (Rust as baseline, Mojo as test)
echo "Step 3: Comparing benchmark results..."
echo "--------------------------------------"
python3 benchmarks/compare_benchmarks.py "$RUST_RESULTS" "$MOJO_RESULTS" "benchmarks/results/${OUTPUT_PREFIX}comparison.json"

# Show detailed engine information
if grep -q "\\[ENGINE\\]" "$MOJO_OUTPUT" 2>/dev/null; then
    echo ""
    echo "Mojo vs Rust Engine Analysis:"
    echo "=============================="
    echo "Rust uses a single highly optimized regex engine with lazy DFA construction,"
    echo "while Mojo uses a hybrid approach:"
    echo "  - DFA Engine: High-performance deterministic automaton for simple patterns"
    echo "  - NFA Engine: Flexible nondeterministic automaton for complex patterns"
    echo "  - Hybrid Matcher: Intelligently routes patterns to optimal engine"
    echo ""
    echo "Both engines leverage SIMD instructions for character class matching and"
    echo "string scanning, making this comparison particularly interesting for"
    echo "understanding the trade-offs between different regex engine architectures."
fi
echo ""

# Generate visualizations (if matplotlib is available)
echo "Step 4: Generating visualizations..."
echo "------------------------------------"
if python3 -c "import matplotlib" 2>/dev/null; then
    python3 benchmarks/visualize_results.py "benchmarks/results/${OUTPUT_PREFIX}comparison.json" "$OUTPUT_PREFIX"
    echo ""
    echo "Visualizations created successfully!"
else
    echo "Warning: matplotlib not installed. Skipping visualizations."
    echo "Install with: pip install matplotlib"
fi

echo ""
echo "======================================================================"
echo "BENCHMARK COMPARISON COMPLETE!"
echo "======================================================================"
echo ""
echo "Results saved in benchmarks/results/:"
echo "  - ${OUTPUT_PREFIX}rust_results.json    : Raw Rust benchmark data"
echo "  - ${OUTPUT_PREFIX}mojo_results.json    : Raw Mojo benchmark data"
echo "  - ${OUTPUT_PREFIX}comparison.json      : Detailed comparison data"
if python3 -c "import matplotlib" 2>/dev/null; then
    echo "  - ${OUTPUT_PREFIX}speedup_chart.png    : Bar chart of speedup factors"
    echo "  - ${OUTPUT_PREFIX}time_comparison.png  : Side-by-side time comparison"
    echo "  - ${OUTPUT_PREFIX}category_analysis.png: Performance by regex category"
fi
echo ""
echo "Key Insights:"
echo "  - Rust regex crate is highly optimized with lazy DFA construction"
echo "  - Mojo's hybrid approach may show different performance characteristics"
echo "  - SIMD optimizations in both engines provide interesting comparisons"
echo "  - Pattern complexity significantly affects engine choice in Mojo"
echo ""
