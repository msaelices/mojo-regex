from time import perf_counter_ns as now
from sys.info import simdwidthof

# Import the SIMD operations module
from regex.simd_ops import CharacterClassSIMD, create_ascii_digits

fn benchmark_digit_search() raises:
    """Benchmark digit character class matching with SIMD optimizations."""
    print("Benchmarking SIMD digit character class matching...")
    
    # Create test data with mixed content
    var test_data = String()
    for i in range(10000):
        test_data += "abc123def456xyz789"
    
    print("Test data length:", len(test_data))
    
    # Create SIMD matcher for digits
    var digit_matcher = create_ascii_digits()
    
    # Warm up
    _ = digit_matcher.find_first_match(test_data)
    
    # Benchmark find_first_match
    var start = now()
    var first_match = digit_matcher.find_first_match(test_data)
    var find_first_time = now() - start
    print("\nfind_first_match:")
    print("  First digit at position:", first_match)
    print("  Time:", find_first_time, "ns")
    
    # Benchmark count_matches
    start = now()
    var count = digit_matcher.count_matches(test_data)
    var count_time = now() - start
    print("\ncount_matches:")
    print("  Total digits found:", count)
    print("  Time:", count_time, "ns")
    print("  Throughput:", Float64(len(test_data)) / Float64(count_time) * 1e9 / 1e6, "MB/s")
    
    # Verify correctness
    var manual_count = 0
    for i in range(len(test_data)):
        var ch = test_data[i]
        if ord(ch) >= ord('0') and ord(ch) <= ord('9'):
            manual_count += 1
    
    print("\nVerification:")
    print("  Manual count:", manual_count)
    print("  Match:", count == manual_count)


fn benchmark_hex_matcher() raises:
    """Benchmark our new hex digit matcher."""
    print("\n\nBenchmarking nibble-based hex digit matcher...")
    
    from regex.simd_matchers import create_hex_digit_matcher
    
    # Create test data
    var test_data = String()
    for i in range(5000):
        test_data += "0123456789ABCDEFabcdef XYZ!@# "
    
    print("Test data length:", len(test_data))
    
    var hex_matcher = create_hex_digit_matcher()
    
    # Benchmark matching
    var start = now()
    var match_count = 0
    var pos = 0
    alias SIMD_WIDTH = 16
    
    while pos + SIMD_WIDTH <= len(test_data):
        var chunk = SIMD[DType.uint8, SIMD_WIDTH](0)
        for i in range(SIMD_WIDTH):
            chunk[i] = ord(test_data[pos + i])
        
        var matches = hex_matcher.match_chunk(chunk)
        for i in range(SIMD_WIDTH):
            if matches[i]:
                match_count += 1
        
        pos += SIMD_WIDTH
    
    var hex_time = now() - start
    print("  Hex digits found:", match_count)
    print("  Time:", hex_time, "ns")
    print("  Throughput:", Float64(pos) / Float64(hex_time) * 1e9 / 1e6, "MB/s")


fn main() raises:
    benchmark_digit_search()
    benchmark_hex_matcher()
    print("\n✅ Benchmark complete!")