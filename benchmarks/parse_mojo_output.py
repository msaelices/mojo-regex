#!/usr/bin/env python3
"""
Parse Mojo benchmark console output and convert to JSON format.
Since Mojo's benchmark API doesn't expose results directly, we parse the console output.
"""

import re
import json
import sys
import os
from datetime import datetime


def parse_mojo_benchmark_output(output: str) -> dict:
    """Parse Mojo benchmark output and extract results.

    Args:
        output: Console output from Mojo benchmark

    Returns:
        Dictionary of benchmark results
    """
    results = {}

    # Pattern to match benchmark result lines:
    # | literal_match_short       |   0.00001621246337890 |   8300 |
    pattern = r'\|\s*(\S+)\s*\|\s*([\d.]+)\s*\|\s*(\d+)\s*\|'

    for line in output.split('\n'):
        match = re.match(pattern, line)
        if match:
            name = match.group(1)
            time_ms = float(match.group(2))
            iterations = int(match.group(3))

            # Convert ms to ns for consistency with Python results
            time_ns = time_ms * 1_000_000

            results[name] = {
                "time_ns": time_ns,
                "time_ms": time_ms,
                "iterations": iterations
            }

    return results


def main():
    """Read Mojo benchmark output from stdin and create JSON file."""
    # Read all input
    output = sys.stdin.read()

    # Parse results
    results = parse_mojo_benchmark_output(output)

    if not results:
        print("Warning: No benchmark results found in output", file=sys.stderr)
        return 1

    # Create JSON output
    json_data = {
        "engine": "mojo",
        "timestamp": datetime.now().isoformat(),
        "results": results
    }

    # Ensure directory exists
    os.makedirs("benchmarks/results", exist_ok=True)

    # Write to file
    output_file = "benchmarks/results/mojo_results.json"
    with open(output_file, "w") as f:
        json.dump(json_data, f, indent=2)

    print(f"Parsed {len(results)} benchmark results")
    print(f"Results exported to {output_file}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
