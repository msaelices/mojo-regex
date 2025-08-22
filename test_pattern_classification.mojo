#!/usr/bin/env mojo

from regex import compile
from regex.optimizer import PatternAnalyzer, PatternComplexity


fn main():
    # Test the national phone validation pattern
    var pattern = "(?:3052(?:0[0-8]|[1-9]\\d)|5056(?:[0-35-9]\\d|4[0-68]))\\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"

    print("Testing national phone validation pattern classification...")
    print("Pattern:", pattern)

    try:
        # Compile the regex to get its AST
        var regex = compile(pattern)
        print("✓ Pattern compiled successfully")

        # Create analyzer and test classification
        var analyzer = PatternAnalyzer()
        var ast = regex.get_ast()  # This method may not exist yet
        var complexity = analyzer.classify(ast)

        print("Pattern complexity:", complexity)

        if complexity.value == PatternComplexity.SIMPLE:
            print("✓ SUCCESS: Pattern classified as SIMPLE (can use DFA)")
        elif complexity.value == PatternComplexity.MEDIUM:
            print(
                "✓ IMPROVEMENT: Pattern classified as MEDIUM (hybrid approach)"
            )
        else:
            print("✗ Still classified as COMPLEX (using slow NFA)")

    except e:
        print("Error testing pattern:", str(e))
        print("This is expected as get_ast() method may not be exposed yet")
