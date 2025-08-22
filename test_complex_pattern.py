#!/usr/bin/env python3

import re

def test_complex_pattern():
    pattern = r"(?:3052(?:0[0-8]|[1-9]\d)|5056(?:[0-35-9]\d|4[0-68]))\d{4}|(?:2742|305[3-9]|472[247-9]|505[2-57-9]|983[2-47-9])\d{6}|(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\d{6}"

    print("=== Testing Complex Pattern with Python ===")
    print("Pattern:", pattern)
    print()

    # Test with sample matching data
    test_cases = [
        "305200123456",    # Should match first alternation
        "505601234567",    # Should match first alternation
        "274212345678",    # Should match second alternation
        "305912345678",    # Should match second alternation
        "212345672890",    # Should match third alternation
        "312345672890",    # Should match third alternation
        "1234567890",      # Should NOT match
        "30520",           # Should NOT match (too short)
    ]

    print("=== Testing Pattern Matches ===")
    compiled = re.compile(pattern)
    for test_str in test_cases:
        result = compiled.match(test_str)
        if result:
            print(f"✅ {test_str} -> MATCH")
        else:
            print(f"❌ {test_str} -> NO MATCH")

    print()

    # Test findall functionality
    print("=== Testing FindAll ===")
    combined_text = "Numbers: 305200123456 and 274212345678 and 212345672890 and invalid 1234567890"
    matches = compiled.findall(combined_text)
    print(f"Found {len(matches)} matches in text")
    for i, match in enumerate(matches, 1):
        print(f"Match {i}: {match}")

if __name__ == "__main__":
    test_complex_pattern()
