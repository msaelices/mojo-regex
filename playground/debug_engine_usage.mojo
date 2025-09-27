#!/usr/bin/env mojo

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
        _ = regex.test(text)
        var end = perf_counter_ns()
        total_time += end - start

    return Float64(total_time) / Float64(iterations) / 1_000_000.0  # ms


fn main() raises:
    print("=== ENGINE USAGE ANALYSIS ===")
    print()

    # Compare different patterns to understand which engine is used
    var patterns = List[String](
        "[0-9]{3}-[0-9]{3}-[0-9]{4}",  # Simple DFA pattern
        "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}",  # Complex phone pattern
    )

    var pattern_names = List[String](
        "Simple Phone DFA",
        "Complex Phone Pattern",
    )

    var test_texts = List[String](
        "555-123-4567",
        "3052001234",
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
        print(
            "Matches '" + test_text + "':",
            "True" if compile_regex(pattern).test(test_text) else "False",
        )
        print()

    print("=== PERFORMANCE COMPARISON ===")
    var simple_time = benchmark_simple(patterns[0], test_texts[0])
    var complex_time = benchmark_simple(patterns[1], test_texts[1])

    print("Simple pattern time: " + String(simple_time) + " ms")
    print("Complex pattern time: " + String(complex_time) + " ms")

    if complex_time > simple_time:
        var ratio = complex_time / simple_time
        print(
            "Complex pattern is "
            + String(ratio)
            + "x slower than simple pattern"
        )
        if ratio > 2.0:
            print(
                "⚠ WARNING: Complex pattern performance suggests NFA usage"
                " despite SIMPLE classification"
            )
        else:
            print(
                "✓ Performance difference is reasonable - optimization may be"
                " working"
            )
    else:
        print(
            "✓ Complex pattern performance is competitive with simple pattern"
        )
