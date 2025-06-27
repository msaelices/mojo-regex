# Mojo Regex Performance Optimization Plan

## Executive Summary

The current mojo-regex implementation is significantly slower than Python's `re` module due to its naive NFA (Non-deterministic Finite Automaton) implementation with excessive backtracking. Benchmark results show Python's `re` module performing operations in 0.006-0.120ms while our implementation would likely be orders of magnitude slower.

This document outlines a comprehensive 3-phase optimization plan that will transform the mojo-regex engine from a simple AST interpreter to a sophisticated multi-engine system capable of competing with Python's highly optimized C implementation.

**Expected Performance Gains:**
- **Phase 1**: 10-100x speedup for simple patterns via DFA compilation
- **Phase 2**: Additional 2-5x speedup through SIMD and bytecode optimization
- **Phase 3**: Final 2-3x speedup via compile-time analysis and advanced algorithms

## Current Performance Analysis

### Identified Bottlenecks

1. **O(n²) Worst-Case Complexity**
   - Current NFA with backtracking has exponential worst-case behavior
   - Every character position requires full AST traversal
   - Python's `re` uses optimized DFA/NFA hybrid with O(n) guarantees

2. **Excessive Function Call Overhead**
   - `_match_node()` called recursively for every character
   - Runtime type dispatch via `ast.type` checks
   - Deep call stacks for complex patterns

3. **Inefficient String Operations**
   - Character-by-character access: `string[str_i]`
   - No SIMD vectorization for character class matching
   - Repeated string slicing creates copies

4. **Memory Allocation Overhead**
   - Creating temporary `Match` objects in inner loops
   - Dynamic `Deque` allocations for match tracking
   - No object pooling or memory reuse

5. **No Pattern Compilation Caching**
   - Regex parsing happens on every `match_first()` call
   - AST construction overhead repeated unnecessarily
   - Python pre-compiles patterns to optimized bytecode

### Performance Comparison

| Operation | Python `re` | Current Mojo | Target Mojo |
|-----------|-------------|--------------|-------------|
| Literal match | 0.120ms | ~12ms (est) | 0.050ms |
| Character class | 0.007ms | ~5ms (est) | 0.005ms |
| Quantifiers | 0.007ms | ~10ms (est) | 0.010ms |
| Complex patterns | 17ms | ~500ms (est) | 20ms |

## Phase 1: DFA Implementation for Simple Patterns

### 1.1 Pattern Classification Engine

Create a `PatternAnalyzer` that categorizes regex complexity:

```mojo
struct PatternAnalyzer:
    fn classify(self, pattern: String) -> PatternComplexity:
        # Analyze AST to determine optimal execution strategy
        pass

enum PatternComplexity:
    SIMPLE      # "hello", "a+", "[a-z]*", "^start", "end$"
    MEDIUM      # "(a|b)+", simple groups, basic quantifiers
    COMPLEX     # Backreferences, lookahead, nested groups
```

**Simple Pattern Criteria:**
- Literal strings with optional anchors: `"^hello$"`
- Single character classes with quantifiers: `"[a-z]+"`
- Simple alternations without nesting: `"a|b|c"`
- Basic quantifiers without backtracking: `"a*"`, `"b+"`

### 1.2 DFA State Machine Implementation

```mojo
struct DFAState:
    var transitions: StaticIntTuple[256, Int]  # ASCII transition table
    var is_accepting: Bool
    var match_info: Optional[MatchInfo]

struct DFAEngine:
    var states: List[DFAState]
    var start_state: Int

    fn compile_pattern(mut self, ast: ASTNode) raises:
        # Convert simple AST patterns to DFA state machine
        # Use Thompson's construction for basic patterns
        pass

    fn match_dfa(self, text: String, start: Int) -> Optional[Match]:
        var current_state = self.start_state
        var pos = start

        while pos < len(text):
            var ch = int(text[pos])
            current_state = self.states[current_state].transitions[ch]

            if current_state == -1:  # No transition, no match
                return None
            if self.states[current_state].is_accepting:
                return Match(0, start, pos + 1, text, "DFA")
            pos += 1

        return None
```

### 1.3 SIMD Character Class Optimization

```mojo
from sys.info import simdwidthof

fn match_char_class_simd[width: Int](text: String, start: Int, char_set: String) -> Int:
    """Vectorized character class matching using SIMD."""
    alias simd_width = simdwidthof[DType.uint8]()

    # Create SIMD bitmask for character class
    var mask = SIMD[DType.uint8, simd_width]()
    # ... populate mask based on char_set

    var pos = start
    while pos + simd_width <= len(text):
        var chunk = text.unsafe_ptr().load[width=simd_width](pos)
        var matches = (chunk & mask) != 0

        if matches.reduce_or():
            # Found match in this chunk, find exact position
            return pos + matches.count_leading_zeros()
        pos += simd_width

    # Handle remaining characters
    while pos < len(text):
        if char_set.find(text[pos]) != -1:
            return pos
        pos += 1

    return -1
```

### 1.4 Hybrid Engine Architecture

```mojo
trait RegexMatcher:
    fn match_first(self, text: String, start: Int) -> Optional[Match]
    fn match_all(self, text: String) -> List[Match]

struct DFAMatcher(RegexMatcher):
    var dfa: DFAEngine

    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        return self.dfa.match_dfa(text, start)

struct NFAMatcher(RegexMatcher):
    var engine: RegexEngine  # Current implementation

    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        return self.engine.match_first(...)

struct HybridMatcher(RegexMatcher):
    var dfa: Optional[DFAMatcher]
    var nfa: NFAMatcher
    var complexity: PatternComplexity

    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        if self.complexity == PatternComplexity.SIMPLE and self.dfa:
            return self.dfa.value().match_first(text, start)
        else:
            return self.nfa.match_first(text, start)
```

## Phase 2: Core Algorithm Optimizations

### 2.1 Boyer-Moore String Search

For literal string patterns, implement Boyer-Moore algorithm:

```mojo
struct BoyerMoore:
    var pattern: String
    var bad_char_table: StaticIntTuple[256, Int]

    fn __init__(mut self, pattern: String):
        self.pattern = pattern
        self._build_bad_char_table()

    fn search(self, text: String) -> Int:
        """O(n) average case string search."""
        var m = len(self.pattern)
        var n = len(text)
        var s = 0  # shift of the pattern

        while s <= n - m:
            var j = m - 1
            while j >= 0 and self.pattern[j] == text[s + j]:
                j -= 1

            if j < 0:
                return s  # Pattern found
            else:
                var bad_char = int(text[s + j])
                s += max(1, j - self.bad_char_table[bad_char])

        return -1
```

### 2.2 Bytecode Virtual Machine

Compile complex patterns to bytecode for efficient execution:

```mojo
enum Opcode:
    CHAR        # Match specific character
    ANY         # Match any character (.)
    CLASS       # Match character class [a-z]
    JUMP        # Unconditional jump
    SPLIT       # Fork execution (for alternation)
    MATCH       # Pattern matched successfully

struct Instruction:
    var opcode: Opcode
    var operand: Int
    var aux_data: String

struct RegexVM:
    var instructions: List[Instruction]
    var stack: List[Int]  # Execution stack for backtracking

    fn execute(self, text: String, start: Int) -> Optional[Match]:
        var pc = 0  # Program counter
        var pos = start

        while pc < len(self.instructions):
            var instr = self.instructions[pc]

            if instr.opcode == Opcode.CHAR:
                if pos < len(text) and text[pos] == chr(instr.operand):
                    pos += 1
                    pc += 1
                else:
                    # Backtrack or fail
                    if not self._backtrack():
                        return None
            elif instr.opcode == Opcode.MATCH:
                return Match(0, start, pos, text, "VM")
            # ... handle other opcodes

        return None
```

### 2.3 Memory Pool Optimization

```mojo
struct MatchPool:
    var pool: List[Match]
    var next_available: Int

    fn get_match(mut self) -> UnsafePointer[Match]:
        """Get a pooled Match object to avoid allocations."""
        if self.next_available < len(self.pool):
            var match = UnsafePointer.address_of(self.pool[self.next_available])
            self.next_available += 1
            return match
        else:
            # Expand pool if needed
            self.pool.append(Match(0, 0, 0, "", ""))
            return self.get_match()

    fn reset(mut self):
        """Reset pool for reuse."""
        self.next_available = 0
```

## Phase 3: Advanced Optimizations

### 3.1 Compile-Time Pattern Specialization

```mojo
@parameter
fn compile_literal_pattern[pattern: StaticString]() -> DFAMatcher:
    """Compile-time pattern compilation for string literals."""
    # Generate optimized DFA at compile time
    # Use constexpr evaluation for maximum performance
    pass

# Usage:
alias email_matcher = compile_literal_pattern["user@example.com"]()
```

### 3.2 Aho-Corasick Multi-Pattern Matching

For alternations like `"abc|def|ghi"`, use Aho-Corasick:

```mojo
struct AhoCorasick:
    var trie: TrieNode
    var failure_links: List[Int]
    var output: List[List[String]]

    fn search_multiple(self, text: String) -> List[Match]:
        """Find all occurrences of multiple patterns in O(n + m + z) time."""
        var matches = List[Match]()
        var state = 0

        for i in range(len(text)):
            var ch = text[i]
            while state != 0 and not self._has_transition(state, ch):
                state = self.failure_links[state]

            if self._has_transition(state, ch):
                state = self._get_transition(state, ch)

            # Check for pattern matches at current state
            for pattern in self.output[state]:
                var start = i - len(pattern) + 1
                matches.append(Match(0, start, i + 1, text, pattern))

        return matches
```

### 3.3 Lazy Quantifier Evaluation

```mojo
struct LazyQuantifier:
    var min_matches: Int
    var max_matches: Int
    var current_matches: Int

    fn should_continue(self, has_more_input: Bool) -> Bool:
        """Decide whether to continue matching based on lazy semantics."""
        if self.current_matches < self.min_matches:
            return True
        if not has_more_input:
            return False
        # Lazy: try to match as few as possible
        return False
```

## Implementation Timeline

### Week 1-2: DFA Foundation
- [ ] **Day 1-3**: Create `PatternAnalyzer` and classification system
- [ ] **Day 4-7**: Implement basic `DFAEngine` for literal patterns
- [ ] **Day 8-10**: Add DFA state machine executor with O(n) matching
- [ ] **Day 11-14**: Create `HybridMatcher` routing logic

**Milestone 1**: Simple literal patterns run in O(n) time

### Week 3-4: SIMD and Optimization
- [ ] **Day 15-18**: Add SIMD character class matching
- [ ] **Day 19-21**: Implement Boyer-Moore string search for literals
- [ ] **Day 22-25**: Optimize quantifier handling (`*`, `+`, `?`)
- [ ] **Day 26-28**: Add pattern compilation caching layer

**Milestone 2**: Character classes and quantifiers show 10-50x speedup

### Week 5-6: Advanced Features
- [ ] **Day 29-32**: Extend DFA to handle simple groups and alternations
- [ ] **Day 33-35**: Implement bytecode compiler for medium complexity
- [ ] **Day 36-38**: Add memory pooling and allocation optimizations
- [ ] **Day 39-42**: Performance testing and benchmarking

**Milestone 3**: All simple-to-medium patterns competitive with Python

## Expected Performance Gains

### Phase 1 Results (DFA Implementation):
| Pattern Type | Current | Target | Speedup |
|--------------|---------|--------|---------|
| Literal strings | ~12ms | 0.05ms | **240x** |
| Character classes | ~5ms | 0.01ms | **500x** |
| Simple quantifiers | ~10ms | 0.02ms | **500x** |
| Anchors | ~8ms | 0.005ms | **1600x** |

### Phase 2 Results (Core Optimizations):
| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Memory allocations | 1000/match | 10/match | **99% reduction** |
| Function call overhead | High | Low | **5x reduction** |
| SIMD utilization | 0% | 80% | **20x speedup** |
| Pattern compilation | Every call | Cached | **100x faster** |

### Phase 3 Results (Advanced Features):
| Feature | Implementation | Expected Gain |
|---------|---------------|---------------|
| Multi-pattern search | Aho-Corasick | **10-100x** |
| Compile-time patterns | Template specialization | **Near C speed** |
| Lazy evaluation | Smart backtracking | **2-3x** |
| Memory layout | Cache-friendly | **20% faster** |

## Risk Mitigation

### 1. Correctness Assurance
- **Maintain comprehensive test suite** - All existing tests must pass
- **Add regression benchmarks** - Performance cannot regress
- **Cross-validation with Python** - Results must match Python's `re` module
- **Fuzzing infrastructure** - Random pattern generation for edge case testing

### 2. Fallback Strategy
```mojo
struct SafeHybridMatcher:
    fn match_first(self, text: String, start: Int) -> Optional[Match]:
        # Try optimized path
        var result = self.optimized_match(text, start)

        # Fallback to reference implementation for verification
        debug_assert(result == self.reference_match(text, start))

        return result
```

### 3. Incremental Deployment
- **Feature flags** for each optimization level
- **A/B testing framework** to compare implementations
- **Performance monitoring** with automatic fallback on regression
- **Gradual rollout** - enable optimizations per pattern type

### 4. Development Practices
- **Benchmark-driven development** - Every change must show measurable improvement
- **Code review focus on correctness** - Optimization should not sacrifice correctness
- **Documentation of algorithms** - Clear explanation of each optimization technique
- **Modular architecture** - Easy to disable/enable specific optimizations

## Technical Implementation Details

### DFA Construction Algorithm

```mojo
fn construct_dfa(ast: ASTNode) -> DFAEngine:
    """Convert AST to DFA using Thompson's construction + subset construction."""

    # Step 1: Convert AST to NFA
    var nfa = ast_to_nfa(ast)

    # Step 2: Convert NFA to DFA using subset construction
    var dfa_states = List[Set[Int]]()  # Each DFA state = set of NFA states
    var transitions = Dict[Tuple[Int, UInt8], Int]()

    # Initial DFA state = epsilon closure of NFA start state
    var start_closure = epsilon_closure(nfa, [nfa.start_state])
    dfa_states.append(start_closure)

    var worklist = [0]  # DFA states to process
    while len(worklist) > 0:
        var dfa_state = worklist.pop()
        var nfa_states = dfa_states[dfa_state]

        # For each possible input character
        for ch in range(256):
            var next_nfa_states = Set[Int]()

            # Collect all NFA states reachable via character ch
            for nfa_state in nfa_states:
                for transition in nfa.transitions[nfa_state]:
                    if transition.symbol == ch:
                        next_nfa_states.add(transition.target)

            if len(next_nfa_states) > 0:
                var next_closure = epsilon_closure(nfa, next_nfa_states)

                # Find or create DFA state for this NFA state set
                var target_dfa_state = find_or_create_dfa_state(dfa_states, next_closure)
                transitions[(dfa_state, ch)] = target_dfa_state

                if target_dfa_state == len(dfa_states) - 1:  # Newly created
                    worklist.append(target_dfa_state)

    return DFAEngine(dfa_states, transitions, start_state=0)
```

### SIMD Character Class Implementation

```mojo
fn build_simd_lookup_table(char_class: String) -> SIMD[DType.uint8, 32]:
    """Build SIMD lookup table for character class matching."""
    var lookup = SIMD[DType.uint8, 32](0)

    # Parse character class like "[a-zA-Z0-9]"
    var i = 1  # Skip opening '['
    while i < len(char_class) - 1:  # Skip closing ']'
        if i + 2 < len(char_class) and char_class[i + 1] == '-':
            # Handle range like "a-z"
            var start_char = ord(char_class[i])
            var end_char = ord(char_class[i + 2])
            for ch in range(start_char, end_char + 1):
                lookup[ch % 32] = 1  # Set bit for this character
            i += 3
        else:
            # Handle single character
            var ch = ord(char_class[i])
            lookup[ch % 32] = 1
            i += 1

    return lookup

fn match_char_class_vectorized(text: String, start: Int, lookup: SIMD[DType.uint8, 32]) -> Int:
    """Vectorized character class matching."""
    alias CHUNK_SIZE = 32
    var pos = start

    while pos + CHUNK_SIZE <= len(text):
        # Load 32 characters at once
        var chars = text.unsafe_ptr().load[width=CHUNK_SIZE](pos)

        # Create indices for lookup (chars % 32)
        var indices = chars & SIMD[DType.uint8, CHUNK_SIZE](31)

        # Gather from lookup table
        var matches = lookup.gather(indices)

        # Check if any character matches
        if matches.reduce_or():
            # Find first match position
            for i in range(CHUNK_SIZE):
                if matches[i]:
                    return pos + i

        pos += CHUNK_SIZE

    # Handle remaining characters
    while pos < len(text):
        var ch = ord(text[pos])
        if lookup[ch % 32]:
            return pos
        pos += 1

    return -1
```

## Conclusion

This optimization plan transforms the mojo-regex engine from a naive NFA interpreter to a sophisticated multi-engine system capable of competing with Python's highly optimized `re` module. The phased approach ensures steady progress while maintaining correctness, with each phase delivering measurable performance improvements.

The combination of DFA compilation, SIMD optimization, bytecode execution, and advanced algorithms will result in a regex engine that not only matches Python's performance but potentially exceeds it by leveraging Mojo's compile-time optimization capabilities.

**Success Metrics:**
- Simple patterns: Match or exceed Python performance
- Complex patterns: Within 2x of Python performance
- Memory usage: 50% reduction compared to current implementation
- Compilation time: Sub-millisecond pattern compilation

This plan provides a clear roadmap for achieving these ambitious performance goals while maintaining the correctness and reliability expected from a production regex library.
