## Regex in Mojo

### Building a Hybrid DFA/NFA Engine with SIMD Optimization

<div style="text-align: center;">
<img src="./image/logo.png" alt="regex engine">
</div>

---

# Agenda

### Part 1: Introduction & Motivation

**1. What is mojo-regex?**
<!-- .element: class="fragment" data-fragment-index="1" -->

**2. Why Build a Regex Engine in Mojo?**
<!-- .element: class="fragment" data-fragment-index="2" -->

**3. Performance Comparison**
<!-- .element: class="fragment" data-fragment-index="3" -->

### Part 2: Architecture Deep Dive

**4. Hybrid DFA/NFA Design**
<!-- .element: class="fragment" data-fragment-index="4" -->

**5. Component Overview**
<!-- .element: class="fragment" data-fragment-index="5" -->

### Part 3: Performance Optimizations

**6. SIMD and Memory Optimizations**
<!-- .element: class="fragment" data-fragment-index="6" -->

**7. Practical Examples & Benchmarks**
<!-- .element: class="fragment" data-fragment-index="7" -->

---

# 📚 Resources

- **GitHub Repository** [github.com/msaelices/mojo-regex](https://github.com/msaelices/mojo-regex)

- **Installation Guide**
```bash
pixi add mojo-regex
```

- **Performance Tips** [docs/performance-tips.md](https://github.com/msaelices/mojo-regex/blob/main/docs/performance-tips.md)

- **Contributing Guide** [CONTRIBUTING.md](https://github.com/msaelices/mojo-regex/blob/main/CONTRIBUTING.md)

---

<!-- .slide: class="center-slide" -->
# Part 1: Introduction & Motivation

---

### What is mojo-regex?

A regex library for Mojo featuring:

- 🏎️ **Hybrid DFA/NFA Architecture** - Best of both worlds
- ⚡ **SIMD-Accelerated Matching** - Vectorized operations
- 🐍 **Python-Compatible API** - Familiar interface
- 🚀 **O(n) Performance** - For common patterns
- 🔧 **Zero-Copy Operations** (WIP) - Memory efficient

---

### Current Features

#### ✅ Implemented
- Basic elements: literals, wildcards (`a`, `.`)
- Character classes: `[a-z]`, `[^0-9]`
- Quantifiers: `*`, `+`, `?`, `{n}`, `{n,m}`
- Anchors: `^`, `$`
- Groups and alternation: `(abc)`, `a|b`
- Global matching: `findall()`

#### 🚧 In Progress
- Predefined classes: `\d`, `\w`, `\s`
- Non-capturing groups: `(?:...)`
- Case-insensitive matching
- Match replacement: `sub()`, `gsub()`

---

### Why Build a Regex Engine in Mojo?

**Just problem solving!**
- At Smith.ai, needed a high-performance phone number parser
- Build smith-phonenums, based on python-phonenumbers
- Turns out regex is the bottleneck

**Alternatives:**
- Import Python's `re` module from Mojo
- Parsing numbers without regexs

**Hard mode:**
- Build a regex engine in Mojo "from scratch"
- Thanks to LLMs, entry barrier was much lower

### Performance Comparison

| Pattern Type | Python `re` | mojo-regex | Speedup |
|--------------|-------------|------------|---------|
| Literal match | 0.120ms | 0.050ms | 2.4x |
| Character class | 0.007ms | 0.005ms | 1.4x |
| Simple quantifiers | 0.007ms | 0.010ms | 0.7x |
| Complex patterns | 17ms | 20ms | 0.85x |

**Key Insights:**
- ✅ Competitive with highly-optimized C implementation
- ⚡ Faster for literal patterns (SIMD string search)
- 🎯 Room for improvement in complex patterns

Note: Benchmarks on typical text processing workloads

---

<!-- .slide: class="center-slide" -->
# Part 2: Architecture Deep Dive

---

### The Hybrid DFA/NFA Approach

**Traditional Approaches:**
- **DFA Only**: Fast O(n) but limited features, exponential states
- **NFA Only**: Full features but O(nm) with backtracking

**Our Solution: Intelligent Routing**

```
Pattern → Analyzer → Simple? → DFA Engine (O(n))
                 ↓
              Complex? → NFA Engine (Full features)
```

🧠 **Smart Design**: Use the right tool for the job!

---

### Architecture Overview

```
Input: "hello.*world"
        ↓
   📝 Lexer
        ↓
   🔣 Tokens: [ELEMENT(h), ELEMENT(e), ..., WILDCARD, ASTERISK, ...]
        ↓
   🌳 Parser
        ↓
   🎯 AST: RE → [ELEMENT(hello), WILDCARD(quantified), ELEMENT(world)]
        ↓
   🧠 Optimizer (Pattern Analysis)
        ↓
   🔀 HybridMatcher
      ├─ 🏎️ DFA Engine (simple patterns)
      └─ 🔄 NFA Engine (complex patterns)
        ↓
   📊 Match Results
```

---

### Component Details: Lexer & Parser

**Lexer** (`lexer.mojo`)
```mojo
fn scan(regex: String) -> List[Token]:
    # Tokenize: "a+" → [ELEMENT('a'), PLUS()]
```

**Parser** (`parser.mojo`)
```mojo
fn parse(tokens: List[Token]) -> ASTNode:
    # Build AST with proper precedence
    # Handle groups, alternation, quantifiers
```

**Key Design**: Clean separation of concerns

---

### The AST: Index-Based Architecture

**Traditional Approach:**
```mojo
struct ASTNode:
    var children: List[ASTNode]  # Copies everywhere!
```

**Our Approach:**
```mojo
struct Regex:
    var children_ptr: UnsafePointer[ASTNode]  # All nodes here
    var children_len: Int

struct ASTNode:
    var children_indexes: SIMD[DType.uint8, 256]  # Just indices!
    var regex_ptr: UnsafePointer[Regex]  # Back reference
```

🚀 **Benefits**: No copies, cache-friendly, SIMD potential

---

### Pattern Complexity Analysis

```mojo
struct PatternAnalyzer:
    fn classify(self, ast: ASTNode) -> PatternComplexity:
        # Analyze pattern features
        
        if self._is_literal_only(ast):
            return PatternComplexity.SIMPLE  # → DFA
            
        if self._has_simple_quantifiers(ast):
            return PatternComplexity.SIMPLE  # → DFA
            
        if self._has_groups_or_alternation(ast):
            return PatternComplexity.COMPLEX  # → NFA
```

**Classification drives performance!**

---

### DFA Engine Implementation

```mojo
struct DFAEngine:
    var states: List[DFAState]
    
    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        var current_state = self.start_state
        var pos = start
        
        while pos < len(text):
            var char_code = ord(text[pos])
            current_state = self.states[current_state].transitions[char_code]
            
            if current_state == -1:  # No transition
                return None
                
            if self.states[current_state].is_accepting:
                return Match(start, pos + 1, text)
                
            pos += 1
```

⚡ **O(n) guaranteed** - No backtracking!

---

<!-- .slide: class="center-slide" -->
# Part 3: Performance Optimizations

---

### SIMD Character Class Matching

**The Challenge**: Check if character is in `[a-z]`

**Traditional Approach:**
```mojo
# Check each character one by one
if char >= 'a' and char <= 'z':
    match!
```

**SIMD Approach:**
```mojo
struct CharacterClassSIMD:
    var lookup_table: SIMD[DType.uint8, 256]
    
    fn _check_chunk_simd(self, text: String, pos: Int):
        var chunk = text.unsafe_ptr().load[width=16](pos)
        var result = self.lookup_table._dynamic_shuffle(chunk)
        return result != 0  # 16 chars checked at once!
```

🚀 **16x theoretical speedup!**

---

### SIMD Optimization Details

**Dynamic Shuffle Magic** (commit 265edd7)
```mojo
@parameter
if SIMD_WIDTH == 16 or SIMD_WIDTH == 32:
    # Use native pshufb/tbl1 instructions
    var result = self.lookup_table._dynamic_shuffle(chunk)
    return result != 0
```

**Hybrid Approach** (commit 3e2cf21)
```mojo
fn __init__(out self, char_class: String):
    # Small classes (≤3 chars): Direct comparison
    # Large classes: Lookup table with SIMD
    self.use_shuffle_optimization = len(char_class) > 3
```

💡 **Key Insight**: SIMD has overhead - use wisely!

---

### Memory Optimizations

**Register-Passable Structs**
```mojo
@register_passable("trivial")
struct SIMDStringSearch:
    var pattern_length: Int  # 8 bytes
    var first_char_simd: SIMD[DType.uint8, 16]  # 16 bytes
    # Total: 24 bytes - fits in registers!
```

**Benefits:**
- ✅ No heap allocations
- ✅ No reference counting
- ✅ CPU register passing
- ✅ Better cache locality

---

### Caching Strategies

**Global SIMD Matcher Cache** (commit cecd978)
```mojo
var _digit_matcher_cache = _Global[
    Optional[RangeBasedMatcher],
    Optional[RangeBasedMatcher](None),
    _initialize_digit_matcher,
]

fn get_digit_matcher() -> RangeBasedMatcher:
    """Get cached matcher, creating if necessary."""
    var cached = _digit_matcher_cache.get_value()
    if not cached:
        cached = Optional(create_digit_matcher())
        _digit_matcher_cache.set_value(cached)
    return cached.value()
```

🎯 **One allocation, used everywhere!**

---

### Compile-Time Optimizations

**Static ASCII Values**
```mojo
# Before: Runtime computation
if ord(char) >= ord('0') and ord(char) <= ord('9'):

# After: Compile-time constants
alias CHAR_ZERO = ord('0')
alias CHAR_NINE = ord('9')
if char_code >= CHAR_ZERO and char_code <= CHAR_NINE:
```

**Specialized Matchers**
```mojo
fn create_hex_matcher() -> NibbleBasedMatcher:
    """Optimized for [0-9a-fA-F] using bit operations."""
    return NibbleBasedMatcher()
```

---

### Real-World Performance Impact

**Literal String Search** (SIMD-optimized)
```mojo
# Finding "example.com" in text
var searcher = SIMDStringSearch("example.com")
var pos = searcher.search(text, 0)
```
- ⚡ 2.4x faster than Python's `re`
- 🎯 Uses Boyer-Moore-style first character check

**Character Class Matching**
```mojo
# Pattern: [a-z]+
var matcher = CharacterClassSIMD("abcdefghijklmnopqrstuvwxyz")
```
- ⚡ Process 16-32 characters per instruction
- 🎯 Automatic vectorization

---

<!-- .slide: class="center-slide" -->
# Part 4: Practical Examples

---

### Basic Usage

```mojo
from regex import match_first, findall, search

# Simple literal matching
var result = match_first("hello", "hello world")
if result:
    print("Match found:", result.value().get_match_text())
    # Output: Match found: hello

# Find all matches
var matches = findall("a", "banana")
print("Found", len(matches), "matches")
# Output: Found 3 matches

# Character classes
var emails = findall(
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    "Contact john@example.com or mary@test.org"
)
# Finds both email addresses
```

---

### Advanced Patterns

```mojo
# Quantifiers
match_first("a+", "aaaa")      # Matches "aaaa"
match_first("a{2,4}", "aaaaa") # Matches "aaaa"

# Anchors
match_first("^hello", "hello world")  # ✓ Matches
match_first("^world", "hello world")  # ✗ No match

# Groups and alternation
match_first("(com|org|net)", "example.com")  # Matches "com"

# Complex patterns
var url_pattern = "^https?://[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
match_first(url_pattern, "https://example.com")  # ✓ Valid URL
```

---

### Performance Best Practices

**1. Reuse Compiled Patterns**
```mojo
# Good: Compile once
var pattern = CompiledRegex("[0-9]+")
for text in texts:
    var matches = pattern.match_all(text)

# Bad: Recompile every time
for text in texts:
    var matches = findall("[0-9]+", text)
```

**2. Use Simple Patterns When Possible**
```mojo
# Prefer DFA-eligible patterns
match_first("error", log_line)  # O(n) with SIMD

# Over complex alternatives
match_first("err(or)?", log_line)  # May use NFA
```

---

### Benchmarking Example

```mojo
from time import perf_counter_ns as now
from regex import match_first

fn benchmark_literal_match():
    var text = "hello world" * 1000
    var pattern = "world"
    
    var start = now()
    for _ in range(1000):
        var result = match_first(pattern, text)
        keep(result.__bool__())  # Prevent optimization
    
    var elapsed = now() - start
    print("Time per match:", elapsed / 1000, "ns")

# Results:
# mojo-regex: ~50ns per match
# Python re:  ~120ns per match
```

---

### Integration Tips

**1. Error Handling**
```mojo
try:
    var result = match_first(user_pattern, text)
except:
    print("Invalid regex pattern")
```

**2. Building Complex Patterns**
```mojo
# Use raw strings for cleaner patterns
alias EMAIL_PATTERN = r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"

# Build patterns programmatically
var words = ["error", "warning", "fatal"]
var pattern = "(" + "|".join(words) + ")"
```

---

### Future Roadmap

**Coming Soon:**
- 📝 Predefined character classes (`\d`, `\w`, `\s`)
- 🔄 Non-greedy quantifiers (`*?`, `+?`)
- 🎯 Named capture groups
- 🔧 Match replacement (`sub()`, `gsub()`)
- 🌍 Unicode support

**Long Term:**
- 👀 Lookahead/lookbehind assertions
- 🔗 Backreferences
- 📊 Compile-time pattern optimization
- 🚀 GPU acceleration for parallel matching

---

### Contributing

**How to Contribute:**

1. **Check the TO-DO list** in README.md
2. **Read CONTRIBUTING.md** for architecture details
3. **Run benchmarks** before/after changes
4. **Add tests** for new features

**Good First Issues:**
- Implement `\d` character class
- Add case-insensitive flag
- Improve error messages
- Add more benchmarks

---

### Performance Tips Summary

**Do's:**
- ✅ Use DFA-eligible patterns when possible
- ✅ Reuse compiled patterns
- ✅ Leverage SIMD for character classes
- ✅ Profile before optimizing

**Don'ts:**
- ❌ Don't use complex patterns for simple tasks
- ❌ Don't recompile patterns in loops
- ❌ Don't ignore pattern complexity
- ❌ Don't assume NFA is always slower

---

<!-- .slide: class="center-slide" -->
# Thank You! 🔥

## Questions & Discussion

**Resources:**
- GitHub: [github.com/msaelices/mojo-regex](https://github.com/msaelices/mojo-regex)
- Docs: [Performance Tips](https://github.com/msaelices/mojo-regex/blob/main/docs/performance-tips.md)
- Install: `pixi add mojo-regex`

_Let's build high-performance text processing together!_

Note: Thank you for your interest in mojo-regex! Feel free to contribute, report issues, or share your use cases. The Mojo ecosystem is growing, and regex is a fundamental building block.
