# Regex
Regex Library for Mojo


`regex` is a regex library featuring a hybrid DFA/NFA engine architecture that automatically optimizes pattern matching based on complexity.

It aims to provide a similar interface as the [re](https://docs.python.org/3/library/re.html) stdlib package while leveraging Mojo's performance capabilities.

## Disclaimer ⚠️

This software is in an early stage of development. Even though it is functional, it is not yet feature-complete and may contain bugs. Check the features section below and the TO-DO sections for the current status

## Implemented Features

### Basic Elements
- ✅ Literal characters (`a`, `hello`)
- ✅ Wildcard (`.`) - matches any character except newline
- ✅ Whitespace (`\s`) - matches space, tab, newline, carriage return, form feed
- ✅ Escape sequences (`\t` for tab, `\\` for literal backslash)

### Character Classes
- ✅ Character ranges (`[a-z]`, `[0-9]`, `[A-Za-z0-9]`)
- ✅ Negated ranges (`[^a-z]`, `[^0-9]`)
- ✅ Mixed character sets (`[abc123]`)
- ✅ Character ranges within groups (`(b|[c-n])`)

### Quantifiers
- ✅ Zero or more (`*`)
- ✅ One or more (`+`)
- ✅ Zero or one (`?`)
- ✅ Exact count (`{3}`)
- ✅ Range count (`{2,4}`)
- ✅ Minimum count (`{2,}`)
- ✅ Quantifiers on all elements (characters, wildcards, ranges, groups)

### Anchors
- ✅ Start of string (`^`)
- ✅ End of string (`$`)
- ✅ Anchors in OR expressions (`^na|nb$`)

### Groups and Alternation
- ✅ Capturing groups (`(abc)`)
- ✅ Alternation/OR (`a|b`)
- ✅ Complex OR patterns (`(a|b)`, `na|nb`)
- ✅ Nested alternations (`(b|[c-n])`)
- ✅ Group quantifiers (`(a)*`, `(abc)+`)

### Engine Features
- ✅ **Hybrid DFA/NFA Architecture** - Automatic engine selection for optimal performance
- ✅ **O(n) Performance** - DFA engine for simple patterns (literals, basic quantifiers, character classes)
- ✅ **Full Regex Support** - NFA engine with backtracking for complex patterns
- ✅ **Pattern Complexity Analysis** - Intelligent routing between engines
- ✅ **SIMD Optimization** - Vectorized character class matching
- ✅ **Pattern Compilation Caching** - Pre-compiled patterns for reuse
- ✅ **Match Position Tracking** - Precise start_idx, end_idx reporting
- ✅ **Simple API**: `match_first(pattern, text) -> Optional[Match]`


## Installation

1. **Install [pixi](https://pixi.sh/latest/)**

2. **Add the Package** (at the top level of your project):

    ```bash
    pixi add mojo-regex
    ```

## Example Usage

```mojo
from regex import match_first, findall

# Basic literal matching
var result = match_first("hello", "hello world")
if result:
    print("Match found:", result.value().get_match_text())

# Find all matches
var matches = findall("a", "banana")
print("Found", len(matches), "matches:")
for i in range(len(matches)):
    print("  Match", i, ":", matches[i].get_match_text(), "at position", matches[i].start_idx)

# Wildcard and quantifiers
result = match_first(".*@.*", "user@domain.com")
if result:
    print("Email found")

# Find all numbers in text
var numbers = findall("[0-9]+", "Price: $123, Quantity: 456, Total: $579")
for i in range(len(numbers)):
    print("Number found:", numbers[i].get_match_text())

# Character ranges
result = match_first("[a-z]+", "hello123")
if result:
    print("Letters:", result.value().get_match_text())

# Groups and alternation
result = match_first("(com|org|net)", "example.com")
if result:
    print("TLD found:", result.value().get_match_text())

# Find all domains in text
var domains = findall("(com|org|net)", "Visit example.com or test.org for more info")
for i in range(len(domains)):
    print("Domain found:", domains[i].get_match_text())

# Anchors
result = match_first("^https?://", "https://example.com")
if result:
    print("Valid URL")

# Complex patterns
result = match_first("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", "user@example.com")
if result:
    print("Valid email format")

# Find all email addresses in text
var emails = findall("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", "Contact john@example.com or mary@test.org")
for i in range(len(emails)):
    print("Email found:", emails[i].get_match_text())

# === OPTIMIZATION SHOWCASE EXAMPLES ===
# These patterns now benefit from DFA optimization!

# Large alternation (8 branches) - DFA-optimized
var fruit_pattern = "(apple|banana|cherry|date|elderberry|fig|grape|honey)"
var fruit_text = "I love eating apple and banana for breakfast"
var fruits = findall(fruit_pattern, fruit_text)
for i in range(len(fruits)):
    print("Fruit found:", fruits[i].get_match_text())

# Deep nested alternation (depth 4) - DFA-optimized
var nested_pattern = "(?:(?:(?:a|b)|(?:c|d))|(?:(?:e|f)|(?:g|h)))"
var nested_result = match_first(nested_pattern, "Testing with character a")
if nested_result:
    print("Deep nested match:", nested_result.value().get_match_text())

# Literal-heavy alternation (80% threshold) - DFA-optimized
var user_pattern = "(user123|admin456|guest789|root000|test111|demo222)"
var login_text = "Login attempts: user123 failed, admin456 success"
var users = findall(user_pattern, login_text)
for i in range(len(users)):
    print("User found:", users[i].get_match_text())

# Complex phone patterns - DFA-optimized
var phone_pattern = "[0-9]{3}-[0-9]{3}-[0-9]{4}"  # DFA-optimized
var phone_text = "Call us at 555-123-4567 or 800-555-9999"
var phones = findall(phone_pattern, phone_text)
for i in range(len(phones)):
    print("Phone found:", phones[i].get_match_text())

# Complex group (5 children) - DFA-optimized
var complex_pattern = "(hello|world|test|demo|sample)[0-9]{3}[a-z]{2}"
var complex_text = "Found: hello123ab, world456cd, test789ef in data"
var complex_matches = findall(complex_pattern, complex_text)
for i in range(len(complex_matches)):
    print("Complex match:", complex_matches[i].get_match_text())
```

## Performance

The hybrid DFA/NFA architecture provides significant performance benefits:

### Pattern Performance Characteristics

| Pattern Type | Engine Used | Time Complexity | SIMD Optimization | Example |
|--------------|-------------|-----------------|-------------------|---------|
| **Literal strings** | DFA + SIMD | O(n/w) | String search vectorization | `"hello"`, `"example.com"` |
| **Character classes** | DFA + SIMD | O(n/w) | Lookup table vectorization | `"[a-z]+"`, `"[0-9]+"` |
| **Built-in classes** | DFA/NFA + SIMD | O(n/w) | Pre-built SIMD matchers | `"\d+"`, `"\s+"` |
| **Simple quantifiers** | DFA + SIMD | O(n/w) | Vectorized counting | `"a*"`, `"[0-9]{3}"` |
| **Anchors** | DFA | O(1) | Position validation | `"^start"`, `"end$"` |
| **Basic groups** | DFA/NFA + SIMD | O(n) to O(nm) | Partial vectorization | `"(abc)+"`, `"([a-z]+)"` |
| **Small alternation** | DFA + SIMD | O(n/w) | DFA state optimization | `"cat\|dog"`, `"(a\|b\|c)"` |
| **Large alternation** | DFA + SIMD | O(n/w) | **Extended to 8 branches** | `"(apple\|banana\|...\|honey)"` |
| **Literal-heavy alternation** | DFA + SIMD | O(n/w) | **80% threshold detection** | `"(user123\|admin456\|...)"` |
| **Deep nested groups** | DFA/NFA + SIMD | O(n) to O(nm) | **Depth 4 support** | `"(?:(?:(?:a\|b)\|(?:c\|d))\|...)"` |
| **Complex phone patterns** | DFA + SIMD | O(n/w) | **Now DFA-optimized** | US national phone validation |
| **Complex patterns** | NFA + SIMD | O(nm) to O(2^n) | Character-level SIMD | Backreferences, lookahead |

*Where w = SIMD width (typically 16-32 characters processed per instruction)*

## Building and Testing

```bash
# Build the package
./tools/build.sh

# Run tests
./tools/run-tests.sh

# Or run specific test
mojo test -I src/ tests/test_matcher.mojo

# Run benchmarks to see performance including SIMD optimizations
mojo benchmarks/bench_engine.mojo

# Run SIMD-specific tests
mojo test -I src/ tests/test_simd_integration.mojo
```

## TO-DO: Missing Features

### High Priority
- [x] Global matching (`findall()`)
- [x] Hybrid DFA/NFA engine architecture
- [x] Pattern complexity analysis and optimization
- [x] SIMD-accelerated character class matching
- [x] SIMD-accelerated literal string search
- [x] SIMD capability detection and automatic routing
- [x] Vectorized quantifier processing for character classes
- [ ] Non-capturing groups (`(?:...)`)
- [ ] Named groups (`(?<name>...)` or `(?P<name>...)`)
- [ ] Predefined character classes (`\d`, `\w`, `\S`, `\D`, `\W`)
- [ ] Case insensitive matching options
- [ ] Match replacement (`sub()`, `gsub()`)
- [ ] String splitting (`split()`)

### Medium Priority
- [ ] Non-greedy quantifiers (`*?`, `+?`, `??`)
- [ ] Word boundaries (`\b`, `\B`)
- [ ] Match groups extraction and iteration
- [ ] Pattern compilation object
- [ ] Unicode character classes (`\p{L}`, `\p{N}`)
- [ ] Multiline mode (`^` and `$` match line boundaries)
- [ ] Dot-all mode (`.` matches newlines)

### Advanced Features
- [ ] Positive lookahead (`(?=...)`)
- [ ] Negative lookahead (`(?!...)`)
- [ ] Positive lookbehind (`(?<=...)`)
- [ ] Negative lookbehind (`(?<!...)`)
- [ ] Backreferences (`\1`, `\2`)
- [ ] Atomic groups (`(?>...)`)
- [ ] Possessive quantifiers (`*+`, `++`)
- [ ] Conditional expressions (`(?(condition)yes|no)`)
- [ ] Recursive patterns
- [ ] Subroutine calls

### Engine Improvements
- [x] Hybrid DFA/NFA architecture with automatic engine selection
- [x] O(n) DFA engine for simple patterns
- [x] SIMD optimization for character class matching and literal string search
- [x] Pattern complexity analysis for optimal routing
- [x] SIMD capability detection for intelligent engine selection
- [x] Vectorized operations for quantifiers and repetition counting
- [x] **Extended DFA pattern support** - Large alternations (up to 8 branches)
- [x] **Deep nesting support** - Groups up to depth 4
- [x] **Literal-heavy alternation detection** - 80% threshold optimization
- [x] **Selective optimization** - High-value, low-overhead improvements only
- [x] **Analysis overhead reduction** - Early termination and selective analysis
- [x] **Cross-language performance validation** - Benchmarking vs Python/Rust
- [ ] Compile-time pattern specialization for string literals
- [ ] Aho-Corasick multi-pattern matching for alternations
- [ ] Advanced NFA optimizations (lazy quantifiers, cut operators)
- [ ] Parallel matching for multiple patterns
- [ ] One-Pass DFA for advanced capturing groups
- [ ] Lazy DFA construction for very large pattern sets

## Optimization Strategy

The regex engine uses a **selective optimization approach** to extend DFA coverage while avoiding performance regressions:

### Pattern Classification System

Patterns are automatically classified into three categories:

- **SIMPLE**: DFA-optimized with O(n) performance - literals, basic quantifiers, character classes, optimized alternations
- **MEDIUM**: Hybrid DFA/NFA approach - complex groups, medium alternations, some phone patterns
- **COMPLEX**: NFA with backtracking - backreferences, lookahead, very complex nesting

### Selective Optimization Criteria

Optimizations are applied only when they provide clear benefits:

1. **Extended Alternation Support**: Increased from 3→8 branches for DFA optimization
2. **Deep Nesting Tolerance**: Groups now supported up to depth 4 (vs. 3 previously)
3. **Literal-Heavy Detection**: 80% threshold for alternations with mostly literal branches
4. **Complex Group Support**: Up to 5 children in groups (vs. 3 previously)
5. **Early Termination**: Analysis functions use selective branching to reduce overhead

### Performance Validation

All optimizations undergo rigorous validation:

- **Cross-language benchmarking** against Python and Rust implementations
- **Regression testing** to ensure no performance degradation on existing patterns
- **Analysis overhead measurement** to validate optimization efficiency
- **Real-world pattern testing** with complex phone validation and email patterns

This approach ensures that optimizations extend engine capabilities without compromising the performance characteristics that make the main implementation effective.

## Contributing

Contributions are welcome! If you'd like to contribute, please follow the contribution guidelines in the [CONTRIBUTING.md](CONTRIBUTING.md) file in the repository.

## Acknowledgments

Thanks to Claude Code for helping a lot with the implementation and testing of the regex library, and to the Mojo community for their support and feedback.

## License

mojo is licensed under the [MIT license](LICENSE).

---

[![Language](https://img.shields.io/badge/language-mojo-orange)](https://www.modular.com/mojo)
[![License](https://img.shields.io/github/license/msaelices/mojo-regex?logo=github)](https://github.com/msaelices/mojo-regex/blob/main/LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/contributors-welcome!-blue)](https://github.com/msaelices/mojo-regex#contributing)
![CodeQL](https://github.com/msaelices/mojo-regex/workflows/CodeQL/badge.svg)
