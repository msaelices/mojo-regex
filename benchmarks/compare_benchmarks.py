#!/usr/bin/env python3
"""
Generic benchmark comparison tool that can compare any two benchmark results.
Supports both Python vs Mojo and branch vs branch comparisons.
"""

import json
import sys
from typing import Tuple


def load_results(filename: str) -> dict:
    """Load benchmark results from JSON file.

    Args:
        filename: Path to JSON results file

    Returns:
        Dictionary with benchmark data
    """
    try:
        with open(filename, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Results file '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{filename}': {e}", file=sys.stderr)
        sys.exit(1)


def calculate_speedup(baseline_time: float, test_time: float) -> float:
    """Calculate speedup factor (how many times faster test is vs baseline).

    Args:
        baseline_time: Time taken by baseline implementation
        test_time: Time taken by test implementation

    Returns:
        Speedup factor (>1 means test is faster than baseline)
    """
    if test_time == 0:
        return float("inf")
    return baseline_time / test_time


def format_time(time_ms: float) -> str:
    """Format time in human-readable format.

    Args:
        time_ms: Time in milliseconds

    Returns:
        Formatted time string
    """
    if time_ms < 0.001:
        return f"{time_ms * 1000:.3f} μs"
    elif time_ms < 1:
        return f"{time_ms:.3f} ms"
    else:
        return f"{time_ms:.2f} ms"


def detect_comparison_type(baseline_results: dict, test_results: dict) -> tuple:
    """Detect the type of comparison being performed.

    Returns:
        Tuple of (baseline_name, test_name, comparison_title)
    """
    baseline_engine = baseline_results.get("engine", "unknown")
    test_engine = test_results.get("engine", "unknown")

    # Check if it's Python vs Mojo comparison
    if baseline_engine.lower() == "python" and test_engine.lower() == "mojo":
        return ("Python", "Mojo", "MOJO REGEX VS PYTHON REGEX BENCHMARK COMPARISON")
    elif baseline_engine.lower() == "mojo" and test_engine.lower() == "python":
        # Reverse case - swap them
        return ("Mojo", "Python", "PYTHON REGEX VS MOJO REGEX BENCHMARK COMPARISON")
    else:
        # Branch comparison or generic comparison
        # Try to extract branch info from timestamp or use generic names
        baseline_name = "Baseline"
        test_name = "Test"

        # If both are mojo, it's likely a branch comparison
        if baseline_engine.lower() == "mojo" and test_engine.lower() == "mojo":
            baseline_name = "Other Branch"
            test_name = "Current Branch"
            title = "CURRENT BRANCH VS OTHER BRANCH BENCHMARK COMPARISON"
        else:
            title = (
                f"{test_name.upper()} VS {baseline_name.upper()} BENCHMARK COMPARISON"
            )

        return (baseline_name, test_name, title)


def create_comparison_report(
    baseline_results: dict, test_results: dict
) -> Tuple[dict, str]:
    """Create a comparison report between two benchmark results.

    Args:
        baseline_results: Baseline benchmark results (e.g., Python or Other branch)
        test_results: Test benchmark results (e.g., Mojo or Current branch)

    Returns:
        Tuple of (comparison_data, formatted_report)
    """
    # Detect comparison type
    baseline_name, test_name, comparison_title = detect_comparison_type(
        baseline_results, test_results
    )

    comparison_data = {
        "summary": {
            "baseline_engine": baseline_results["engine"],
            "test_engine": test_results["engine"],
            "baseline_timestamp": baseline_results.get("timestamp", "N/A"),
            "test_timestamp": test_results.get("timestamp", "N/A"),
            "baseline_name": baseline_name,
            "test_name": test_name,
            "total_benchmarks": 0,
            "test_faster_count": 0,
            "baseline_faster_count": 0,
            "average_speedup": 0.0,
            "geometric_mean_speedup": 1.0,
        },
        "benchmarks": {},
    }

    # Build comparison data
    all_benchmarks = set(baseline_results["results"].keys()) | set(
        test_results["results"].keys()
    )
    speedups = []

    for benchmark in sorted(all_benchmarks):
        baseline_result = baseline_results["results"].get(benchmark)
        test_result = test_results["results"].get(benchmark)

        if baseline_result and test_result:
            baseline_time = baseline_result["time_ms"]
            test_time = test_result["time_ms"]
            speedup = calculate_speedup(baseline_time, test_time)

            comparison_data["benchmarks"][benchmark] = {
                f"{baseline_name.lower()}_time_ms": baseline_time,
                f"{test_name.lower()}_time_ms": test_time,
                "speedup": speedup,
                f"{baseline_name.lower()}_iterations": baseline_result["iterations"],
                f"{test_name.lower()}_iterations": test_result["iterations"],
                "engine": test_result.get("engine", "N/A"),
            }

            speedups.append(speedup)
            if speedup > 1:
                comparison_data["summary"]["test_faster_count"] += 1
            elif speedup < 1:
                comparison_data["summary"]["baseline_faster_count"] += 1

    # Calculate summary statistics
    if speedups:
        comparison_data["summary"]["total_benchmarks"] = len(speedups)
        comparison_data["summary"]["average_speedup"] = sum(speedups) / len(speedups)

        # Geometric mean (better for ratios)
        product = 1.0
        for s in speedups:
            product *= s
        comparison_data["summary"]["geometric_mean_speedup"] = product ** (
            1.0 / len(speedups)
        )

    # Create formatted report
    report = []
    report.append("=" * 100)
    report.append(comparison_title)
    report.append("=" * 100)
    report.append("")

    # Summary
    summary = comparison_data["summary"]
    report.append("SUMMARY:")
    report.append(f"  Total benchmarks compared: {summary['total_benchmarks']}")
    report.append(f"  {test_name} faster: {summary['test_faster_count']} benchmarks")
    report.append(
        f"  {baseline_name} faster: {summary['baseline_faster_count']} benchmarks"
    )
    report.append(f"  Average speedup: {summary['average_speedup']:.2f}x")
    report.append(f"  Geometric mean speedup: {summary['geometric_mean_speedup']:.2f}x")
    report.append("")
    report.append(
        f"  Note: Speedup > 1.0 means {test_name} is faster than {baseline_name}"
    )
    report.append("")

    # Detailed results
    report.append("DETAILED RESULTS:")
    report.append("-" * 110)
    report.append(
        f"{'Benchmark':<35} {f'{baseline_name} (ms)':>15} {f'{test_name} (ms)':>15} {'Speedup':>10} {'Engine':>8} {'Status':>15}"
    )
    report.append("-" * 110)

    for benchmark, data in sorted(comparison_data["benchmarks"].items()):
        baseline_time = data[f"{baseline_name.lower()}_time_ms"]
        test_time = data[f"{test_name.lower()}_time_ms"]
        speedup = data["speedup"]

        if speedup > 10:
            status = f"🚀 {test_name} wins!"
        elif speedup > 2:
            status = f"✓ {test_name} faster"
        elif speedup > 1.1:
            status = f"→ {test_name} slight"
        elif speedup > 0.9:
            status = "≈ Similar"
        elif speedup > 0.5:
            status = f"← {baseline_name} slight"
        else:
            status = f"⚠ {baseline_name} faster"

        engine = data.get("engine", "N/A")
        report.append(
            f"{benchmark:<35} {format_time(baseline_time):>15} "
            f"{format_time(test_time):>15} {speedup:>9.2f}x {engine:>8} {status:>15}"
        )

    report.append("-" * 110)
    report.append("")

    # Top performers
    sorted_by_speedup = sorted(
        comparison_data["benchmarks"].items(),
        key=lambda x: x[1]["speedup"],
        reverse=True,
    )

    report.append(f"TOP 5 SPEEDUPS ({test_name} vs {baseline_name}):")
    for i, (benchmark, data) in enumerate(sorted_by_speedup[:5]):
        report.append(f"  {i + 1}. {benchmark}: {data['speedup']:.2f}x faster")

    report.append("")
    report.append("BOTTOM 5 SPEEDUPS:")
    for i, (benchmark, data) in enumerate(sorted_by_speedup[-5:]):
        report.append(f"  {i + 1}. {benchmark}: {data['speedup']:.2f}x")

    return comparison_data, "\n".join(report)


def main():
    """Main comparison function."""
    # Get file paths from command line arguments
    if len(sys.argv) < 3:
        print(
            "Usage: compare_benchmarks_generic.py <baseline_results.json> <test_results.json> [output.json]"
        )
        print(
            "  baseline_results.json: Results to compare against (e.g., Python or Other branch)"
        )
        print("  test_results.json: Results to test (e.g., Mojo or Current branch)")
        print(
            "  output.json: Optional output file (default: benchmarks/results/comparison.json)"
        )
        sys.exit(1)

    baseline_file = sys.argv[1]
    test_file = sys.argv[2]
    output_file = (
        sys.argv[3] if len(sys.argv) > 3 else "benchmarks/results/comparison.json"
    )

    # Load results
    baseline_results = load_results(baseline_file)
    test_results = load_results(test_file)

    # Create comparison
    comparison_data, report = create_comparison_report(baseline_results, test_results)

    # Print report
    print(report)

    # Save comparison data
    with open(output_file, "w") as f:
        json.dump(comparison_data, f, indent=2)

    print(f"\nComparison data saved to {output_file}")


if __name__ == "__main__":
    main()
