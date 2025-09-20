#!/usr/bin/env python
"""
Generic visualization for benchmark comparison results.
Works with both Python vs Mojo and branch vs branch comparisons.
"""

import json
import sys
import os

try:
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError:
    print("Error: matplotlib is required for visualization", file=sys.stderr)
    print("Install with: pip install matplotlib", file=sys.stderr)
    sys.exit(1)


def load_comparison_data(filename: str) -> dict:
    """Load comparison data from JSON file.

    Args:
        filename: Path to comparison JSON file

    Returns:
        Dictionary with comparison data
    """
    try:
        with open(filename, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Comparison file '{filename}' not found", file=sys.stderr)
        print("Run compare_benchmarks.py first", file=sys.stderr)
        sys.exit(1)


def get_time_keys(benchmark_data: dict) -> tuple:
    """Extract the time field keys from benchmark data.

    Returns:
        Tuple of (baseline_time_key, test_time_key)
    """
    keys = list(benchmark_data.keys())
    time_keys = [k for k in keys if k.endswith("_time_ms")]

    if len(time_keys) >= 2:
        # Sort to ensure consistent ordering
        time_keys.sort()
        return time_keys[0], time_keys[1]
    else:
        # Fallback to defaults
        return "python_time_ms", "mojo_time_ms"


def create_speedup_chart(comparison_data: dict, output_file: str):
    """Create a bar chart showing speedup factors.

    Args:
        comparison_data: Comparison data dictionary
        output_file: Path to save the chart
    """
    benchmarks = comparison_data["benchmarks"]
    summary = comparison_data["summary"]

    # Get names from summary
    baseline_name = summary.get("baseline_name", "Baseline")
    test_name = summary.get("test_name", "Test")

    # Sort by speedup for better visualization
    sorted_benchmarks = sorted(
        benchmarks.items(), key=lambda x: x[1]["speedup"], reverse=True
    )

    names = [b[0] for b in sorted_benchmarks]
    speedups = [b[1]["speedup"] for b in sorted_benchmarks]

    # Create figure
    fig, ax = plt.subplots(figsize=(14, 10))

    # Create bars with color coding
    colors = []
    for speedup in speedups:
        if speedup > 10:
            colors.append("#00ff00")  # Bright green for huge speedups
        elif speedup > 2:
            colors.append("#66cc66")  # Green for good speedups
        elif speedup > 1.1:
            colors.append("#99cc99")  # Light green for slight speedups
        elif speedup > 0.9:
            colors.append("#cccccc")  # Gray for similar performance
        else:
            colors.append("#ff9999")  # Light red for slower

    y_pos = np.arange(len(names))
    bars = ax.barh(y_pos, speedups, color=colors)

    # Add value labels on bars
    for i, (bar, speedup) in enumerate(zip(bars, speedups)):
        width = bar.get_width()
        label_x = width + 0.1 if width < 20 else width / 2
        color = "black" if width < 20 else "white"
        ha = "left" if width < 20 else "center"
        ax.text(
            label_x,
            bar.get_y() + bar.get_height() / 2,
            f"{speedup:.1f}x",
            ha=ha,
            va="center",
            color=color,
            fontweight="bold",
        )

    # Styling
    ax.set_yticks(y_pos)
    ax.set_yticklabels(names)
    ax.invert_yaxis()
    ax.set_xlabel(
        f"Speedup Factor ({test_name} vs {baseline_name})", fontsize=12
    )
    ax.set_title(
        f"{test_name} Performance vs {baseline_name}",
        fontsize=16,
        fontweight="bold",
    )

    # Add reference line at 1x
    ax.axvline(
        x=1, color="red", linestyle="--", alpha=0.5, label="Equal performance"
    )

    # Add grid
    ax.grid(axis="x", alpha=0.3)

    # Add summary text
    summary_text = (
        f"Geometric Mean Speedup: {summary['geometric_mean_speedup']:.2f}x\n"
        f"{test_name} faster:"
        f" {summary['test_faster_count']}/{summary['total_benchmarks']} benchmarks"
    )
    ax.text(
        0.95,
        0.05,
        summary_text,
        transform=ax.transAxes,
        fontsize=10,
        ha="right",
        va="bottom",
        bbox=dict(boxstyle="round", facecolor="wheat", alpha=0.5),
    )

    # Adjust layout
    plt.tight_layout()

    # Save
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    plt.savefig(output_file, dpi=150, bbox_inches="tight")
    print(f"Speedup chart saved to {output_file}")


def create_time_comparison_chart(comparison_data: dict, output_file: str):
    """Create a grouped bar chart comparing actual execution times.

    Args:
        comparison_data: Comparison data dictionary
        output_file: Path to save the chart
    """
    benchmarks = comparison_data["benchmarks"]
    summary = comparison_data["summary"]

    # Get names from summary
    baseline_name = summary.get("baseline_name", "Baseline")
    test_name = summary.get("test_name", "Test")

    # Get data
    names = sorted(benchmarks.keys())

    # Get the correct time keys from the first benchmark
    if names:
        first_benchmark = benchmarks[names[0]]
        baseline_key, test_key = get_time_keys(first_benchmark)
    else:
        baseline_key, test_key = "python_time_ms", "mojo_time_ms"

    baseline_times = [benchmarks[n].get(baseline_key, 0) for n in names]
    test_times = [benchmarks[n].get(test_key, 0) for n in names]

    # Create figure
    fig, ax = plt.subplots(figsize=(16, 10))

    x = np.arange(len(names))
    width = 0.35

    # Create bars
    bars1 = ax.bar(
        x - width / 2,
        baseline_times,
        width,
        label=baseline_name,
        color="#ff7f0e",
    )
    bars2 = ax.bar(
        x + width / 2, test_times, width, label=test_name, color="#1f77b4"
    )

    # Styling
    ax.set_xlabel("Benchmark", fontsize=12)
    ax.set_ylabel("Time (ms) - Log Scale", fontsize=12)
    ax.set_title(
        f"Execution Time Comparison: {test_name} vs {baseline_name}",
        fontsize=16,
        fontweight="bold",
    )
    ax.set_xticks(x)
    ax.set_xticklabels(names, rotation=45, ha="right")
    ax.legend()

    # Use log scale for better visualization
    ax.set_yscale("log")

    # Add grid
    ax.grid(axis="y", alpha=0.3)

    # Adjust layout
    plt.tight_layout()

    # Save
    plt.savefig(output_file, dpi=150, bbox_inches="tight")
    print(f"Time comparison chart saved to {output_file}")


def create_category_analysis(comparison_data: dict, output_file: str):
    """Create a chart analyzing performance by benchmark category.

    Args:
        comparison_data: Comparison data dictionary
        output_file: Path to save the chart
    """
    benchmarks = comparison_data["benchmarks"]
    summary = comparison_data["summary"]

    # Get names from summary
    baseline_name = summary.get("baseline_name", "Baseline")
    test_name = summary.get("test_name", "Test")

    # Categorize benchmarks
    categories = {
        "Literal Matching": [],
        "Character Classes": [],
        "Quantifiers": [],
        "Anchors": [],
        "Alternation": [],
        "Groups": [],
        "Complex Patterns": [],
        "SIMD Optimized": [],
        "Literal Optimization": [],
    }

    for name, data in benchmarks.items():
        speedup = data["speedup"]

        if "literal_match" in name:
            categories["Literal Matching"].append(speedup)
        elif "range_" in name or "char_class" in name:
            categories["Character Classes"].append(speedup)
        elif "quantifier" in name or "wildcard" in name:
            categories["Quantifiers"].append(speedup)
        elif "anchor" in name:
            categories["Anchors"].append(speedup)
        elif "alternation" in name:
            categories["Alternation"].append(speedup)
        elif "group" in name:
            categories["Groups"].append(speedup)
        elif "complex" in name:
            categories["Complex Patterns"].append(speedup)
        elif "simd" in name:
            categories["SIMD Optimized"].append(speedup)
        elif "literal_prefix" in name or "required_literal" in name:
            categories["Literal Optimization"].append(speedup)
        else:
            # Try to categorize based on pattern
            if "match_all" in name:
                categories["Quantifiers"].append(speedup)

    # Calculate average speedup per category
    cat_names = []
    cat_speedups = []
    cat_counts = []

    for cat, speedups in categories.items():
        if speedups:
            cat_names.append(cat)
            cat_speedups.append(np.mean(speedups))
            cat_counts.append(len(speedups))

    # Create figure
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))

    # Average speedup by category
    y_pos = np.arange(len(cat_names))
    bars = ax1.barh(y_pos, cat_speedups, color="skyblue")

    # Add value labels
    for bar, speedup in zip(bars, cat_speedups):
        width = bar.get_width()
        ax1.text(
            width + 0.1,
            bar.get_y() + bar.get_height() / 2,
            f"{speedup:.2f}x",
            ha="left",
            va="center",
        )

    ax1.set_yticks(y_pos)
    ax1.set_yticklabels(cat_names)
    ax1.invert_yaxis()
    ax1.set_xlabel("Average Speedup Factor", fontsize=12)
    ax1.set_title(
        (
            f"Average Performance by Regex Category ({test_name} vs"
            f" {baseline_name})"
        ),
        fontsize=14,
        fontweight="bold",
    )
    ax1.grid(axis="x", alpha=0.3)
    ax1.axvline(x=1, color="red", linestyle="--", alpha=0.5)

    # Number of benchmarks per category
    bars2 = ax2.bar(cat_names, cat_counts, color="lightcoral")
    ax2.set_xlabel("Category", fontsize=12)
    ax2.set_ylabel("Number of Benchmarks", fontsize=12)
    ax2.set_title(
        "Benchmark Distribution by Category", fontsize=14, fontweight="bold"
    )
    ax2.tick_params(axis="x", rotation=45)

    # Add count labels
    for bar, count in zip(bars2, cat_counts):
        height = bar.get_height()
        ax2.text(
            bar.get_x() + bar.get_width() / 2.0,
            height,
            f"{count}",
            ha="center",
            va="bottom",
        )

    # Adjust layout
    plt.tight_layout()

    # Save
    plt.savefig(output_file, dpi=150, bbox_inches="tight")
    print(f"Category analysis saved to {output_file}")


def main():
    """Main visualization function."""
    # Get file paths from command line arguments or use defaults
    comparison_file = (
        sys.argv[1] if len(sys.argv)
        > 1 else "benchmarks/results/comparison.json"
    )
    prefix = sys.argv[2] if len(sys.argv) > 2 else ""

    # Load comparison data
    comparison_data = load_comparison_data(comparison_file)

    print("Creating visualizations...")

    # Create different charts with prefix
    speedup_file = f"benchmarks/results/{prefix}speedup_chart.png"
    time_file = f"benchmarks/results/{prefix}time_comparison.png"
    category_file = f"benchmarks/results/{prefix}category_analysis.png"

    create_speedup_chart(comparison_data, speedup_file)
    create_time_comparison_chart(comparison_data, time_file)
    create_category_analysis(comparison_data, category_file)

    print("\nAll visualizations created successfully!")
    print("Check the benchmarks/results/ directory for:")
    print(f"  - {prefix}speedup_chart.png")
    print(f"  - {prefix}time_comparison.png")
    print(f"  - {prefix}category_analysis.png")


if __name__ == "__main__":
    main()
