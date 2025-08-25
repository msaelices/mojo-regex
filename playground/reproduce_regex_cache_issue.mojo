from regex import match_first, findall, search


fn make_test_string(length: Int) -> String:
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
    var text = (
        "hello world this is a test with hello again and hello there" * 100
    )
    var result = findall("hello", text)
    return len(result)


fn main() raises:
    print("=== EXACT REPRODUCTION FROM WORKING CASE ===")

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
    else:
        print("\nNo corruption - something about the context is different")
