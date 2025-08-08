#!/bin/bash

# Script to compare performance before and after optimizations

echo "=== Performance Comparison ==="
echo "This script compares performance between main branch and optimization branch"
echo

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Function to run benchmarks
run_benchmarks() {
    local branch=$1
    local output_file=$2

    echo "Running benchmarks on branch: $branch..."
    mojo -I src benchmarks/bench_engine.mojo > "$output_file.bench_engine" 2>&1
}

# Run benchmarks on current branch
echo
echo "=== Running benchmarks on current branch ==="
run_benchmarks "$CURRENT_BRANCH" "results_current_branch"

# Switch to main branch
echo
echo "=== Switching to main branch ==="
git checkout main

# Run benchmarks on main branch
echo
echo "=== Running benchmarks on main branch ==="
run_benchmarks "main" "results_main"

# Switch back to original branch
echo
echo "=== Switching back to $CURRENT_BRANCH ==="
git checkout "$CURRENT_BRANCH"

# Create comparison report
echo
echo "=== Creating comparison report ==="
cat > performance_comparison.md << 'EOF'
# SIMD Performance Comparison Report

## Benchmark Results

#### Main Branch
```
EOF

# Add main branch results
echo '```' >> performance_comparison.md
tail -n 30 results_main.bench_engine >> performance_comparison.md
echo '```' >> performance_comparison.md

echo "" >> performance_comparison.md
echo "#### Optimization Branch" >> performance_comparison.md
echo '```' >> performance_comparison.md
tail -n 30 results_current_branch.bench_engine >> performance_comparison.md
echo '```' >> performance_comparison.md

# Add other benchmark results similarly...

echo
echo "=== Performance comparison complete ==="
echo "Results saved to:"
echo "  - performance_comparison.md (summary)"
echo "  - results_main.* (raw main branch results)"
echo "  - results_current_branch.* (raw optimization branch results)"
echo
echo "To view the summary: cat performance_comparison.md"
