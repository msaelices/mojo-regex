# Mojo Regex Performance Tips and Tricks

This guide documents performance optimization techniques learned from developing the mojo-regex library. These tips are based on actual optimizations implemented in the codebase and demonstrate how to leverage Mojo's unique features for high-performance regex matching.

## Table of Contents
1. [Architectural Optimizations](#architectural-optimizations)
2. [SIMD and Vectorization](#simd-and-vectorization)
3. [Memory Management](#memory-management)
4. [Compile-Time Optimizations](#compile-time-optimizations)
5. [Algorithmic Optimizations](#algorithmic-optimizations)
6. [Caching Strategies](#caching-strategies)
7. [Benchmarking and Profiling](#benchmarking-and-profiling)
8. [Best Practices Summary](#best-practices-summary)

## Architectural Optimizations

### Hybrid DFA/NFA Architecture

The most significant performance improvement comes from using different engines for different pattern types:

```mojo
# From matcher.mojo
struct HybridMatcher:
    """Routes patterns to optimal engine based on complexity analysis."""

    fn __init__(out self, pattern: String) raises:
        var analyzer = PatternAnalyzer()
        var complexity = analyzer.analyze_pattern(self.ast)

        if complexity == PatternComplexity.SIMPLE:
            self._dfa_matcher = DFAMatcher(self.ast)  # O(n) performance
        else:
            self._nfa_matcher = NFAMatcher(self.ast, pattern)  # Full regex support
```

**Key Insight**: Not all regex patterns need the full power of an NFA with backtracking. Simple patterns can be executed in O(n) time using a DFA.

### Pattern Complexity Analysis

Analyze patterns to determine the optimal execution strategy:

```mojo
# From optimizer.mojo
fn analyze_pattern(self, ast: ASTNode) -> PatternComplexity:
    # Simple patterns: literals, character classes, basic quantifiers
    if self._is_simple_pattern(ast):
        return PatternComplexity.SIMPLE

    # Medium patterns: simple groups, alternations
    if self._has_simple_groups(ast):
        return PatternComplexity.MEDIUM

    # Complex patterns: backreferences, lookahead, nested groups
    return PatternComplexity.COMPLEX
```

## SIMD and Vectorization

### Character Class Matching with SIMD

One of the most impactful optimizations is using SIMD for character class matching:

```mojo
# From simd_ops.mojo - commit 265edd7
fn _check_chunk_simd(self, text: String, pos: Int) -> SIMD[DType.bool, SIMD_WIDTH]:
    """Check a chunk of characters using SIMD operations."""
    var chunk = text.unsafe_ptr().load[width=SIMD_WIDTH](pos)

    @parameter
    if SIMD_WIDTH == 16 or SIMD_WIDTH == 32:
        # Fast path: use _dynamic_shuffle for 16/32-byte chunks
        # Uses native pshufb/tbl1 instructions
        var result = self.lookup_table._dynamic_shuffle(chunk)
        return result != 0
```

**Performance Impact**: This optimization replaced a per-character loop with a single SIMD instruction, providing up to 16x speedup for character class matching.

### Hybrid SIMD Approach

Not all patterns benefit equally from SIMD. Use a hybrid approach:

```mojo
# From simd_ops.mojo - commit 3e2cf21
fn __init__(out self, owned char_class: String):
    self.use_shuffle_optimization = len(char_class) > 3

    if self.use_shuffle_optimization:
        # Use lookup table for larger character classes
        self._initialize_lookup_table(char_class)
    else:
        # Direct comparison for small classes
        self.chars = char_class
```

**Key Insight**: SIMD shuffle operations have overhead. For small character classes (≤3 chars), direct comparison is faster.

### SIMD String Search

Implement vectorized string search for literal patterns:

```mojo
# From simd_ops.mojo - commit 5d11c94
@register_passable("trivial")
struct SIMDStringSearch:
    """SIMD-accelerated string search inspired by Rust's regex engine."""

    fn search(self, pattern: String, text: String, start: Int = 0) -> Int:
        # Fast path for short patterns
        if self.pattern_length < 4:
            return self._search_short(pattern, text, start)

        # SIMD search for longer patterns
        var first_char_simd = SIMD[DType.uint8, 16](ord(pattern[0]))
        var pos = start

        while pos + 16 <= len(text):
            var chunk = text.unsafe_ptr().load[width=16](pos)
            var matches = chunk == first_char_simd

            if matches.reduce_or():
                # Check full pattern at matching positions
                for i in range(16):
                    if matches[i] and self._verify_match(pattern, text, pos + i):
                        return pos + i
            pos += 16
```

## Memory Management

### Register-Passable Structs

Make frequently-copied structs register-passable to avoid heap allocations:

```mojo
# From register-passable-optimization.md
@register_passable("trivial")
struct SIMDStringSearch:
    var pattern_length: Int  # 8 bytes
    var first_char_simd: SIMD[DType.uint8, 16]  # 16 bytes
    # Total: 24 bytes - fits in registers
```

**Benefits**:
- No reference counting overhead
- Cheaper copies (register-to-register moves)
- Better cache locality

### Index-Based AST Node References

Avoid storing and copying AST nodes by using index references:

```mojo
# From ast.mojo - current implementation
struct ASTNode:
    var children_indexes: SIMD[DType.uint8, 256]  # Store child indices, not nodes
    var children_len: Int
    var regex_ptr: UnsafePointer[Regex]  # Reference to parent containing all nodes

    @always_inline
    fn get_child(self, i: Int) -> ASTNode[ImmutableAnyOrigin]:
        """Get child by index without copying."""
        return self.regex_ptr[].get_child(Int(self.children_indexes[i] - 1))
```

**Key Benefits**:
- **No AST node copies**: Children are accessed by index reference
- **Compact storage**: Only 256 bytes for child indices vs. potentially large node copies
- **Cache-friendly**: Sequential index access patterns
- **SIMD-friendly**: Child indices stored in SIMD vector for potential parallel operations

**Impact**: This architecture eliminates AST node copies entirely during traversal, significantly reducing memory allocations and improving pattern matching performance.

### Zero-Copy String Operations

Avoid string allocations in hot paths:

```mojo
# From parser.mojo - commit 2958a9f
# Before: Using String allocations
var char = String(token.value)  # Allocates!

# After: Using codepoints directly
var codepoint = ord(token.value[0])  # No allocation
```

## Compile-Time Optimizations

### Using Parameters for Static Values

Move runtime computations to compile-time where possible:

```mojo
# From dfa.mojo - commit c9abc37
# Compile-time ASCII values
alias ORD_0 = ord("0")
alias ORD_9 = ord("9")
alias ORD_A = ord("A")
alias ORD_Z = ord("Z")

fn is_digit(char: Int) -> Bool:
    return char >= ORD_0 and char <= ORD_9  # No runtime ord() calls
```

### Specialized Matcher Generation

Create specialized matchers at compile-time for common patterns:

```mojo
# From simd_matchers.mojo - commit ca74b10
fn create_digit_matcher() -> RangeBasedMatcher:
    """Create optimized matcher for \d patterns."""
    return RangeBasedMatcher(ord("0"), ord("9"))

fn create_hex_matcher() -> NibbleBasedMatcher:
    """Create optimized matcher for hex digits using nibble operations."""
    return NibbleBasedMatcher()
```

## Algorithmic Optimizations

### Literal String Extraction

Extract literal prefixes/suffixes for fast filtering:

```mojo
# From optimizer.mojo - commit 5d11c94
fn extract_literal_prefix(self, ast: ASTNode) -> Optional[String]:
    """Extract literal prefix for Boyer-Moore-style optimization."""
    if ast.type == ASTNodeType.ELEMENT:
        return ast.value
    elif ast.type == ASTNodeType.RE and ast.num_children > 0:
        # Check if first child is literal
        return self.extract_literal_prefix(ast.get_child(0))
```

### Early Termination

Add fast paths for common cases:

```mojo
# From nfa.mojo
fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
    # Fast path: empty pattern
    if self.ast.num_children == 0:
        return Match(start, start, text)

    # Fast path: literal optimization
    if self.literal_prefix:
        var pos = self._find_literal(text, start)
        if pos == -1:
            return None  # Early termination
```

### Character Range Optimization

Optimize character range operations:

```mojo
# From dfa.mojo - commit b2d284f
fn expand_character_range(start: String, end: String) -> String:
    """Expand character range without excessive allocations."""
    var start_code = ord(start[0])
    var end_code = ord(end[0])

    # Pre-allocate exact size needed
    var result = String()
    result.reserve(end_code - start_code + 1)

    for code in range(start_code, end_code + 1):
        result += chr(code)
    return result
```

## Caching Strategies

### Global SIMD Matcher Caching

Cache frequently-used SIMD matchers globally:

```mojo
# From simd_matchers.mojo - commit cecd978
var _digit_matcher_cache = _Global[
    Optional[RangeBasedMatcher],
    Optional[RangeBasedMatcher](None),
    _initialize_digit_matcher,
]

fn get_digit_matcher() -> RangeBasedMatcher:
    """Get cached digit matcher, creating if necessary."""
    var cached = _digit_matcher_cache.get_value()
    if not cached:
        cached = Optional(create_digit_matcher())
        _digit_matcher_cache.set_value(cached)
    return cached.value()
```

**Benefits**: Eliminates repeated allocations for common matchers across the codebase.

### Pattern Compilation Caching

Cache compiled patterns to avoid recompilation:

```mojo
# From matcher.mojo
var _regex_cache = Dict[String, CompiledRegex]()

fn compile_regex(pattern: String) -> CompiledRegex:
    if pattern in _regex_cache:
        return _regex_cache[pattern]

    var compiled = CompiledRegex(pattern)
    _regex_cache[pattern] = compiled
    return compiled
```

## Benchmarking and Profiling

### Effective Benchmarking

Structure benchmarks to measure real performance:

```mojo
# From bench_engine.mojo
@parameter
fn bench_literal_match[text_length: Int, pattern: StaticString](mut b: Bencher):
    var test_text = make_test_string[text_length]()

    @always_inline
    @parameter
    fn call_fn():
        for _ in range(100):  # Multiple iterations for stability
            var result = match_first(pattern, test_text)
            keep(result.__bool__())  # Prevent optimization

    b.iter[call_fn]()
```

### Common Performance Pitfalls

1. **String Allocations in Loops**
   ```mojo
   # Bad: Allocates string each iteration
   for i in range(len(text)):
       var char = String(text[i])

   # Good: Work with integers
   for i in range(len(text)):
       var char_code = ord(text[i])
   ```

2. **Unnecessary Copies**
   ```mojo
   # Bad: Copies entire AST node
   var child = ast.children[i]

   # Good: Use reference
   var child_ref = ast.get_child(i)
   ```

3. **Missing SIMD Opportunities**
   ```mojo
   # Bad: Character-by-character
   for i in range(len(text)):
       if is_digit(text[i]):
           count += 1

   # Good: Process 16 chars at once
   var digit_matcher = get_digit_matcher()
   var matches = digit_matcher.check_chunk(text, pos)
   count += matches.reduce_add()
   ```

## Best Practices Summary

### Do's
1. ✅ Use hybrid architectures - different algorithms for different pattern types
2. ✅ Leverage SIMD for character operations - 16x speedup potential
3. ✅ Make small structs register-passable - avoid heap allocations
4. ✅ Cache expensive computations - especially SIMD matchers
5. ✅ Use compile-time parameters for static values
6. ✅ Profile before optimizing - measure actual bottlenecks
7. ✅ Implement fast paths for common cases
8. ✅ Pre-allocate memory when size is known

### Don'ts
1. ❌ Don't allocate strings in hot loops
2. ❌ Don't copy large data structures unnecessarily
3. ❌ Don't use SIMD for very small operations (overhead > benefit)
4. ❌ Don't ignore algorithmic complexity - O(n) beats optimized O(n²)
5. ❌ Don't optimize prematurely without benchmarks

### Future Optimization Opportunities

1. **Compile-Time Pattern Specialization**: Generate specialized code for literal patterns at compile-time
2. **Aho-Corasick for Alternations**: Use multi-pattern matching for `(word1|word2|...)`
3. **Parallel Matching**: Process multiple patterns or text segments concurrently
4. **JIT Compilation**: Generate machine code for hot patterns
5. **Advanced DFA Minimization**: Reduce state count for complex patterns

## Conclusion

The key to high-performance regex matching in Mojo is combining:
- Smart architectural decisions (hybrid engines)
- Low-level optimizations (SIMD, register-passable)
- Algorithmic improvements (pattern analysis, caching)
