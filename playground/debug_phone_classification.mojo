#!/usr/bin/env mojo

from regex.matcher import compile_regex
from regex.parser import parse
from regex.optimizer import PatternAnalyzer, PatternComplexity


fn main() raises:
    print("=== US PHONE PATTERN CLASSIFICATION DEBUG ===")
    print()

    # The complex national phone validation pattern from the optimization branch
    var phone_pattern = "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"

    print("Pattern:", phone_pattern[:60] + "...")
    print()

    # Parse the pattern to get AST
    var ast = parse(phone_pattern)
    print("✓ Pattern parsed successfully")

    # Create analyzer and test classification
    var analyzer = PatternAnalyzer()
    var complexity = analyzer.classify(ast)

    print("Pattern complexity:", String(complexity.value))

    var complexity_name: String
    if complexity.value == PatternComplexity.SIMPLE:
        complexity_name = "SIMPLE (DFA eligible)"
    elif complexity.value == PatternComplexity.MEDIUM:
        complexity_name = "MEDIUM (Hybrid/Advanced DFA)"
    else:
        complexity_name = "COMPLEX (NFA only)"

    print("Classification: " + complexity_name)
    print()

    # Test the optimization analysis
    var opt_info = analyzer.analyze_optimizations(ast)
    print("=== OPTIMIZATION ANALYSIS ===")
    print("Suggested engine:", opt_info.suggested_engine)
    print(
        "Has literal prefix:",
        "True" if opt_info.has_literal_prefix else "False",
    )
    print("Literal prefix length:", String(opt_info.literal_prefix_length))
    print(
        "Has required literal:",
        "True" if opt_info.has_required_literal else "False",
    )
    print("Required literal length:", String(opt_info.required_literal_length))
    print(
        "Benefits from SIMD:",
        "True" if opt_info.benefits_from_simd else "False",
    )
    print()

    # Test the actual matcher to see which engine it uses
    print("=== MATCHER ANALYSIS ===")
    var regex = compile_regex(phone_pattern)
    print("✓ Regex compiled successfully")

    # Test actual performance on a sample
    var test_phone = "3052001234"
    var result = regex.test(test_phone)
    print(
        "Test phone '" + test_phone + "' matches:",
        "True" if result else "False",
    )

    print()
    print("=== DIAGNOSIS SUMMARY ===")
    if complexity.value == PatternComplexity.SIMPLE:
        print("✓ SUCCESS: Pattern is SIMPLE - should use fast DFA")
    elif complexity.value == PatternComplexity.MEDIUM:
        print("◐ PARTIAL: Pattern is MEDIUM - should use hybrid/advanced DFA")
        print(
            "  Check if advanced engines (One-Pass, Lazy DFA) are implemented"
        )
    else:
        print("✗ PROBLEM: Pattern is COMPLEX - using slow NFA")
        print("  Need to investigate why optimization logic failed")
