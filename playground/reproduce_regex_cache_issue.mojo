#!/usr/bin/env mojo
"""
Regex Cache Corruption Investigation - Phase 1 Test Harness
Following proposal: proposals/regex-cache-corruption-analysis.md

This test systematically investigates which global cache system is causing
the state corruption by testing each cache clearing function individually.
"""

from regex import match_first, findall, search
from regex.matcher import clear_regex_cache

# Import global cache access functions to create clearing functions
from regex.simd_ops import _get_simd_matchers
from regex.simd_matchers import _get_range_matchers, _get_nibble_matchers


fn make_test_string(length: Int) -> String:
    """Create test string of specified length."""
    var result = String()
    var pattern = String("abcdefghijklmnopqrstuvwxyz")
    var pattern_len = len(pattern)
    var full_repeats = length // pattern_len
    var remainder = length % pattern_len
    for _ in range(full_repeats):
        result += pattern
    for i in range(remainder):
        result += pattern[i]
    return result


fn test_findall() raises -> Int:
    """Test function to check for corruption - should return 300 matches."""
    var text = (
        "hello world this is a test with hello again and hello there" * 100
    )
    var result = findall("hello", text)
    return len(result)


fn clear_range_matchers():
    """Clear the global range matchers cache."""
    var matchers_ptr = _get_range_matchers()
    matchers_ptr[].clear()


fn clear_nibble_matchers():
    """Clear the global nibble matchers cache."""
    var matchers_ptr = _get_nibble_matchers()
    matchers_ptr[].clear()


fn clear_simd_matchers():
    """Clear the global SIMD matchers cache."""
    var matchers_ptr = _get_simd_matchers()
    matchers_ptr[].clear()


fn trigger_corruption() raises:
    """Execute the known corruption trigger sequence."""
    var text_10000 = make_test_string(10000) + "hello world"
    var text_range_10000 = make_test_string(10000) + "0123456789"

    print("   Executing corruption trigger sequence:")
    print("     1. match_first('hello', text_10000)")
    _ = match_first("hello", text_10000)

    print("     2. match_first('.*', text_10000)")
    _ = match_first(".*", text_10000)

    print("     3. match_first('a*', text_10000)")
    _ = match_first("a*", text_10000)

    print("     4. search('[0-9]+', text_range_10000)")
    _ = search("[0-9]+", text_range_10000)

    print("   Corruption sequence completed")


fn test_individual_cache_fix(
    cache_name: String, clear_function: fn () -> None
) raises -> Bool:
    """Test if clearing a specific cache fixes the corruption."""
    print("\n=== Testing", cache_name, "Cache Fix ===")

    # Verify initial clean state
    var initial_matches = test_findall()
    if initial_matches != 300:
        print(
            "ERROR: Starting with corrupted state:", initial_matches, "matches"
        )
        return False
    print("Initial state: Clean (300 matches)")

    # Trigger the corruption
    trigger_corruption()

    # Verify corruption occurred
    var corrupted_matches = test_findall()
    if corrupted_matches == 300:
        print("No corruption detected - test sequence didn't trigger the bug")
        return False
    print("Corruption confirmed:", corrupted_matches, "matches (expected 0)")

    # Clear the specific cache
    print("Clearing", cache_name, "cache...")
    clear_function()

    # Test if corruption is fixed
    var fixed_matches = test_findall()
    var is_fixed = fixed_matches == 300

    if is_fixed:
        print("✅ SUCCESS:", cache_name, "cache clearing FIXED the corruption!")
        print("Final state:", fixed_matches, "matches")
    else:
        print("❌ No fix:", cache_name, "cache clearing did not fix corruption")
        print("Final state:", fixed_matches, "matches")

    return is_fixed


fn test_all_caches_combined() raises -> Bool:
    """Test clearing all caches together as a control."""
    print("\n=== Testing All Caches Combined (Control Test) ===")

    # Verify initial clean state
    var initial_matches = test_findall()
    if initial_matches != 300:
        print(
            "ERROR: Starting with corrupted state:", initial_matches, "matches"
        )
        return False
    print("Initial state: Clean (300 matches)")

    # Trigger the corruption
    trigger_corruption()

    # Verify corruption occurred
    var corrupted_matches = test_findall()
    if corrupted_matches == 300:
        print("No corruption detected - test sequence didn't trigger the bug")
        return False
    print("Corruption confirmed:", corrupted_matches, "matches")

    # Clear all caches
    print("Clearing ALL caches (regex + range + nibble + simd)...")
    clear_regex_cache()
    clear_range_matchers()
    clear_nibble_matchers()
    clear_simd_matchers()

    # Test if corruption is fixed
    var fixed_matches = test_findall()
    var is_fixed = fixed_matches == 300

    if is_fixed:
        print("✅ SUCCESS: All caches clearing FIXED the corruption!")
        print("Final state:", fixed_matches, "matches")
    else:
        print("❌ UNEXPECTED: Even clearing all caches didn't fix corruption")
        print("Final state:", fixed_matches, "matches")

    return is_fixed


fn test_baseline_reproduction() raises -> Bool:
    """Test the original reproduction case to verify current behavior."""
    print("=== BASELINE REPRODUCTION TEST ===")

    # Use the exact same setup from my successful reproduction
    var text_10000 = make_test_string(10000)
    var text_range_10000 = make_test_string(10000) + "0123456789"
    text_10000 += "hello world"

    print("Initial state:", test_findall(), "matches")
    print()

    # Run the EXACT same operations from my successful reproduction
    print("Running exact sequence from successful reproduction:")

    print("1. match_first('hello', text_10000)")
    _ = match_first("hello", text_10000)
    print("   State:", test_findall(), "matches")

    print("2. match_first('.*', text_10000)")
    _ = match_first(".*", text_10000)
    print("   State:", test_findall(), "matches")

    print("3. match_first('a*', text_10000)")
    _ = match_first("a*", text_10000)
    print("   State:", test_findall(), "matches")

    print("4. search('[0-9]+', text_range_10000)")
    _ = search("[0-9]+", text_range_10000)
    print("   Final state:", test_findall(), "matches")

    if test_findall() == 0:
        print("\nCORRUPTION REPRODUCED!")
        print("The corruption requires the specific combination of:")
        print("1. match_first operations on the specific benchmark text")
        print("2. Followed by search() with character ranges")
        return True
    else:
        print("\nNo corruption - bandaid fix is preventing the issue")
        return False


fn main() raises:
    """
    Phase 1 Investigation: Identify which global cache is corrupted.

    Strategy:
    1. Test baseline reproduction to confirm current behavior
    2. Test each individual cache clearing function
    3. Determine which specific cache fix resolves the corruption
    4. Use findings to guide Phase 2 implementation
    """
    print("=== REGEX CACHE CORRUPTION INVESTIGATION - PHASE 1 ===")
    print("Objective: Identify which global cache system causes corruption")
    print("Method: Test individual cache clearing functions")
    print()

    # Step 1: Test baseline behavior with current bandaid fix
    print("STEP 1: Testing baseline behavior...")
    var corruption_occurs = test_baseline_reproduction()
    print()

    if not corruption_occurs:
        print("📋 FINDING: Corruption not reproduced - bandaid fix is working")
        print("   Current state: CompiledRegex caching disabled")
        print(
            "   Action needed: Temporarily re-enable caching to test individual"
            " cache fixes"
        )
        print()
        print(
            "Phase 1 Investigation Complete - No corruption detected with"
            " current fix"
        )
        print(
            "See proposals/regex-cache-corruption-analysis.md for guidance on"
            " re-enabling caching"
        )
        return

    # Step 2: If corruption occurs, test each cache individually
    print("STEP 2: Corruption detected - testing individual cache fixes...")

    var results = List[Bool]()

    try:
        # Test each cache individually
        results.append(test_individual_cache_fix("Regex", clear_regex_cache))
        results.append(
            test_individual_cache_fix("Range Matchers", clear_range_matchers)
        )
        results.append(
            test_individual_cache_fix("Nibble Matchers", clear_nibble_matchers)
        )
        results.append(
            test_individual_cache_fix("SIMD Matchers", clear_simd_matchers)
        )

        # Control test: All caches combined
        results.append(test_all_caches_combined())

    except e:
        print("ERROR during testing:", e)
        return

    # Step 3: Analyze results
    print("\n=== PHASE 1 RESULTS ANALYSIS ===")

    var fixes_found = 0
    var cache_names = List[String]()
    cache_names.append("Regex")
    cache_names.append("Range Matchers")
    cache_names.append("Nibble Matchers")
    cache_names.append("SIMD Matchers")
    cache_names.append("All Combined")

    for i in range(len(results)):
        if results[i]:
            print("✅", cache_names[i], "cache clearing FIXES corruption")
            fixes_found += 1
        else:
            print("❌", cache_names[i], "cache clearing does NOT fix corruption")

    print()
    if fixes_found == 0:
        print("❓ UNEXPECTED: No individual cache clearing fixed corruption")
        print(
            "   This suggests the issue may be more complex than single-cache"
            " corruption"
        )
        print(
            "   Possible causes: timing issues, memory layout, or inter-cache"
            " dependencies"
        )
    elif fixes_found == 1:
        print("🎯 SUCCESS: Found specific cache causing corruption!")
        print(
            "   Phase 2 action: Focus targeted fix on the identified cache"
            " system"
        )
        for i in range(len(results) - 1):  # Exclude "All Combined"
            if results[i]:
                print("   TARGET CACHE:", cache_names[i])
    elif fixes_found > 1 and fixes_found < len(results):
        print("🔗 PARTIAL: Multiple caches involved in corruption")
        print("   Corruption likely involves interaction between cache systems")
        print("   Phase 2 action: Investigate cache interdependencies")

    print()
    print("Phase 1 Investigation Complete")
    print(
        "Next steps documented in proposals/regex-cache-corruption-analysis.md"
    )
