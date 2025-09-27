from time import perf_counter_ns
from regex.matcher import compile_regex
from regex.parser import parse
from regex.optimizer import PatternAnalyzer, PatternComplexity


fn benchmark_simple(pattern: String, text: String) raises -> Float64:
    """Quick benchmark to measure performance."""
    var regex = compile_regex(pattern)
    var iterations = 1000

    var total_time: Int = 0
    for _ in range(iterations):
        var start = perf_counter_ns()
        result = regex.test(text)
        var end = perf_counter_ns()
        total_time += end - start

    return Float64(total_time) / Float64(iterations) / 1_000_000.0  # ms


fn main() raises:
    print("=== ENGINE USAGE ANALYSIS ===")
    print()

    # Compare different patterns to understand which engine is used
    var patterns = List[String](
        "\\w+",  # Simple DFA pattern
    )

    var pattern_names = List[String](
        "Word Characters",
    )

    var test_texts = List[String](
        "This is a test with some words 1234 and symbols!@#",
    )

    for i in range(len(patterns)):
        var pattern = patterns[i]
        var name = pattern_names[i]
        var test_text = test_texts[i]

        print("=== " + name + " ===")
        print("Pattern:", pattern[:50] + ("..." if len(pattern) > 50 else ""))

        # Analyze pattern
        var ast = parse(pattern)
        var analyzer = PatternAnalyzer()
        var complexity = analyzer.classify(ast)
        var opt_info = analyzer.analyze_optimizations(ast)

        print(
            "Complexity: "
            + String(complexity.value)
            + " ("
            + (
                "SIMPLE" if complexity.value
                == PatternComplexity.SIMPLE else "MEDIUM" if complexity.value
                == PatternComplexity.MEDIUM else "COMPLEX"
            )
            + ")"
        )
        print("Suggested engine:", opt_info.suggested_engine)

        # Benchmark performance
        var time_ms = benchmark_simple(pattern, test_text)
        print("Performance: " + String(time_ms) + " ms")
        var compiled_regex = compile_regex(pattern)
        print(
            "Matches '" + test_text + "':",
            "True" if compiled_regex.test(test_text) else "False",
        )
        print()

    print("=== PERFORMANCE COMPARISON ===")
    var time = benchmark_simple(patterns[0], test_texts[0])

    print("Pattern time: " + String(time) + " ms")
