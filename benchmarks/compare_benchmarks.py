#!/usr/bin/env python3
"""
Compare benchmark results between Mojo and Python regex implementations.
"""

import json
import sys
from typing import Dict, Tuple


def load_results(filename: str) -> dict:
    """Load benchmark results from JSON file.

    Args:
        filename: Path to JSON results file

    Returns:
        Dictionary with benchmark data
    """
    try:
        with open(filename, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Results file '{filename}' not found", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in '{filename}': {e}", file=sys.stderr)
        sys.exit(1)


def calculate_speedup(mojo_time: float, python_time: float) -> float:
    """Calculate speedup factor (how many times faster Mojo is).

    Args:
        mojo_time: Time taken by Mojo implementation
        python_time: Time taken by Python implementation

    Returns:
        Speedup factor (>1 means Mojo is faster)
    """
    if mojo_time == 0:
        return float('inf')
    return python_time / mojo_time


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


def create_comparison_report(
    mojo_results: dict,
    python_results: dict
) -> Tuple[dict, str]:
    """Create a comparison report between Mojo and Python results.

    Args:
        mojo_results: Mojo benchmark results
        python_results: Python benchmark results

    Returns:
        Tuple of (comparison_data, formatted_report)
    """
    comparison_data = {
        "summary": {
            "mojo_engine": mojo_results["engine"],
            "python_engine": python_results["engine"],
            "mojo_timestamp": mojo_results["timestamp"],
            "python_timestamp": python_results["timestamp"],
            "total_benchmarks": 0,
            "mojo_faster_count": 0,
            "python_faster_count": 0,
            "average_speedup": 0.0,
            "geometric_mean_speedup": 1.0
        },
        "benchmarks": {}
    }

    # Build comparison data
    all_benchmarks = set(mojo_results["results"].keys()) | set(python_results["results"].keys())
    speedups = []

    for benchmark in sorted(all_benchmarks):
        mojo_result = mojo_results["results"].get(benchmark)
        python_result = python_results["results"].get(benchmark)

        if mojo_result and python_result:
            mojo_time = mojo_result["time_ms"]
            python_time = python_result["time_ms"]
            speedup = calculate_speedup(mojo_time, python_time)

            comparison_data["benchmarks"][benchmark] = {
                "mojo_time_ms": mojo_time,
                "python_time_ms": python_time,
                "speedup": speedup,
                "mojo_iterations": mojo_result["iterations"],
                "python_iterations": python_result["iterations"]
            }

            speedups.append(speedup)
            if speedup > 1:
                comparison_data["summary"]["mojo_faster_count"] += 1
            elif speedup < 1:
                comparison_data["summary"]["python_faster_count"] += 1

    # Calculate summary statistics
    if speedups:
        comparison_data["summary"]["total_benchmarks"] = len(speedups)
        comparison_data["summary"]["average_speedup"] = sum(speedups) / len(speedups)

        # Geometric mean (better for ratios)
        product = 1.0
        for s in speedups:
            product *= s
        comparison_data["summary"]["geometric_mean_speedup"] = product ** (1.0 / len(speedups))

    # Create formatted report
    report = []
    report.append("=" * 100)
    report.append("MOJO REGEX VS PYTHON REGEX BENCHMARK COMPARISON")
    report.append("=" * 100)
    report.append("")

    # Summary
    summary = comparison_data["summary"]
    report.append("SUMMARY:")
    report.append(f"  Total benchmarks compared: {summary['total_benchmarks']}")
    report.append(f"  Mojo faster: {summary['mojo_faster_count']} benchmarks")
    report.append(f"  Python faster: {summary['python_faster_count']} benchmarks")
    report.append(f"  Average speedup: {summary['average_speedup']:.2f}x")
    report.append(f"  Geometric mean speedup: {summary['geometric_mean_speedup']:.2f}x")
    report.append("")

    # Detailed results
    report.append("DETAILED RESULTS:")
    report.append("-" * 100)
    report.append(f"{'Benchmark':<35} {'Mojo (ms)':>12} {'Python (ms)':>12} {'Speedup':>10} {'Status':>15}")
    report.append("-" * 100)

    for benchmark, data in sorted(comparison_data["benchmarks"].items()):
        mojo_time = data["mojo_time_ms"]
        python_time = data["python_time_ms"]
        speedup = data["speedup"]

        if speedup > 10:
            status = "🚀 Mojo wins!"
        elif speedup > 2:
            status = "✓ Mojo faster"
        elif speedup > 1.1:
            status = "→ Mojo slight"
        elif speedup > 0.9:
            status = "≈ Similar"
        elif speedup > 0.5:
            status = "← Python slight"
        else:
            status = "⚠ Python faster"

        report.append(
            f"{benchmark:<35} {format_time(mojo_time):>12} "
            f"{format_time(python_time):>12} {speedup:>9.2f}x {status:>15}"
        )

    report.append("-" * 100)
    report.append("")

    # Top performers
    sorted_by_speedup = sorted(
        comparison_data["benchmarks"].items(),
        key=lambda x: x[1]["speedup"],
        reverse=True
    )

    report.append("TOP 5 SPEEDUPS (Mojo vs Python):")
    for i, (benchmark, data) in enumerate(sorted_by_speedup[:5]):
        report.append(f"  {i+1}. {benchmark}: {data['speedup']:.2f}x faster")

    report.append("")
    report.append("BOTTOM 5 SPEEDUPS:")
    for i, (benchmark, data) in enumerate(sorted_by_speedup[-5:]):
        report.append(f"  {i+1}. {benchmark}: {data['speedup']:.2f}x")

    return comparison_data, "\n".join(report)


def main():
    """Main comparison function."""
    # Load results
    mojo_results = load_results("benchmarks/results/mojo_results.json")
    python_results = load_results("benchmarks/results/python_results.json")

    # Create comparison
    comparison_data, report = create_comparison_report(mojo_results, python_results)

    # Print report
    print(report)

    # Save comparison data
    with open("benchmarks/results/comparison.json", "w") as f:
        json.dump(comparison_data, f, indent=2)

    print(f"\nComparison data saved to benchmarks/results/comparison.json")


if __name__ == "__main__":
    main()
