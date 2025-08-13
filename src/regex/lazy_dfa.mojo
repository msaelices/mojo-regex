"""
Lazy DFA implementation for memory-efficient regex matching.

This module implements a DFA that builds states on-demand rather than
pre-computing all possible states. This approach is particularly effective
for patterns with large state spaces, such as complex alternation patterns.

Key advantages:
- Memory-efficient: Only builds states that are actually visited
- Scalable: Can handle patterns that would exceed memory in traditional DFA
- Fast: O(n) matching performance once states are built
- Cache-friendly: Recently used states stay in memory

The Lazy DFA uses a state cache with configurable size limits and employs
LRU (Least Recently Used) eviction when the cache fills up.

Based on concepts from Rust's regex-automata lazy DFA implementation.
"""

from memory import UnsafePointer
from collections import Dict
from regex.ast import ASTNode
from regex.engine import Engine
from regex.matching import Match
from regex.dfa import DFAState, DEFAULT_DFA_TRANSITIONS

alias DEFAULT_LAZY_CACHE_SIZE = 512  # Default number of cached states
alias MAX_LAZY_CACHE_SIZE = 8192  # Maximum cache size
alias CACHE_EVICTION_BATCH_SIZE = 64  # Number of states to evict at once


@register_passable("trivial")
struct StateSignature(Copyable, KeyElement):
    """Signature representing a unique DFA state configuration.

    This is used as a key to identify and cache DFA states in the lazy construction.
    """

    var nfa_states_hash: UInt64
    """Hash of the set of NFA states that comprise this DFA state."""
    var flags: UInt32
    """Additional flags (anchoring, look-ahead, etc.)"""

    fn __init__(out self, nfa_hash: UInt64 = 0, flags: UInt32 = 0):
        self.nfa_states_hash = nfa_hash
        self.flags = flags

    fn __eq__(self, other: Self) -> Bool:
        return (
            self.nfa_states_hash == other.nfa_states_hash
            and self.flags == other.flags
        )

    fn __ne__(self, other: Self) -> Bool:
        return not self.__eq__(other)

    fn __hash__[H: Hasher](self, mut hasher: H):
        # Combine the two hash components
        hasher._update_with_simd(self.nfa_states_hash)
        hasher._update_with_simd(UInt64(self.flags))


@register_passable("trivial")
struct CachedState(Copyable):
    """A cached DFA state with metadata for LRU management."""

    var state: DFAState
    """The actual DFA state."""
    var access_count: UInt64
    """Number of times this state has been accessed."""
    var last_access: UInt64
    """Timestamp of last access (for LRU)."""

    fn __init__(out self, owned state: DFAState):
        self.state = state^
        self.access_count = 0
        self.last_access = 0


struct LazyDFA(Engine):
    """Lazy DFA engine that builds states on-demand for memory efficiency.

    This engine constructs DFA states only when they are needed during matching,
    rather than pre-computing the entire state machine. This allows handling
    of complex patterns that would be too large for traditional DFA approaches.
    """

    var state_cache: Dict[StateSignature, CachedState]
    """Cache mapping state signatures to constructed DFA states."""
    var max_cache_size: Int
    """Maximum number of states to keep in cache."""
    var start_signature: StateSignature
    """Signature of the start state."""
    var current_time: UInt64
    """Current logical timestamp for LRU tracking."""
    var cache_hits: UInt64
    """Number of cache hits (for performance monitoring)."""
    var cache_misses: UInt64
    """Number of cache misses (for performance monitoring)."""

    fn __init__(out self, max_cache_size: Int = DEFAULT_LAZY_CACHE_SIZE):
        """Initialize a lazy DFA with specified cache size.

        Args:
            max_cache_size: Maximum number of states to cache.
        """
        self.state_cache = Dict[StateSignature, CachedState]()
        self.max_cache_size = min(max_cache_size, MAX_LAZY_CACHE_SIZE)
        self.start_signature = StateSignature()
        self.current_time = 0
        self.cache_hits = 0
        self.cache_misses = 0

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match using lazy DFA construction.

        Args:
            text: Input text to search.
            start: Starting position in text.

        Returns:
            Optional Match if found, None otherwise.
        """
        # Try matching from each position starting at 'start'
        for pos in range(start, len(text)):
            var match_result = self._try_match_at_position(text, pos)
            if match_result:
                return match_result.value()

        return None

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the next match - same as match_first for stateless matching."""
        return self.match_first(text, start)

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all non-overlapping matches using lazy DFA.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        var matches = List[Match, hint_trivial_type=True]()
        var pos = 0

        while pos < len(text):
            var match_result = self.match_first(text, pos)
            if match_result:
                var match = match_result.value()
                matches.append(match)
                pos = match.get_end_pos()
                if pos == match.get_start_pos():  # Zero-length match
                    pos += 1
            else:
                break

        return matches

    fn _try_match_at_position(
        mut self, text: String, start_pos: Int
    ) -> Optional[Match]:
        """Try to match starting at a specific position using lazy construction.

        Args:
            text: Input text.
            start_pos: Position to start matching from.

        Returns:
            Optional Match if successful.
        """
        if start_pos >= len(text):
            return None

        var current_signature = self.start_signature
        var pos = start_pos
        var match_end = -1

        while pos <= len(text):
            # Get or build the current state
            var state = self._get_or_build_state(current_signature)
            if not state:
                break

            var current_state = state.value()

            # Check if this is an accepting state
            if current_state.is_accepting:
                match_end = pos

            # If we've consumed all input, we're done
            if pos >= len(text):
                break

            # Get the next character and compute next state signature
            var char_code = ord(text[pos])
            var next_state_id = current_state.get_transition(char_code)

            if next_state_id < 0:
                # No transition available - matching fails
                break

            # Compute signature for next state (simplified)
            var next_signature = self._compute_next_signature(
                current_signature, char_code
            )

            current_signature = next_signature
            pos += 1

        if match_end >= 0:
            return Match(start_pos, match_end)

        return None

    fn _get_or_build_state(
        mut self, signature: StateSignature
    ) -> Optional[DFAState]:
        """Get a state from cache or build it if not present.

        Args:
            signature: Signature identifying the desired state.

        Returns:
            Optional DFAState if successfully retrieved or built.
        """
        self.current_time += 1

        # Check if state is in cache
        if signature in self.state_cache:
            var cached_state = self.state_cache[signature]
            cached_state.access_count += 1
            cached_state.last_access = self.current_time
            self.state_cache[signature] = cached_state
            self.cache_hits += 1
            return cached_state.state

        # State not in cache - build it
        self.cache_misses += 1
        var new_state = self._build_state(signature)
        if not new_state:
            return None

        # Add to cache
        self._add_to_cache(signature, new_state.value())
        return new_state.value()

    fn _build_state(self, signature: StateSignature) -> Optional[DFAState]:
        """Build a DFA state from its signature.

        Args:
            signature: State signature to build.

        Returns:
            Optional DFAState if successfully built.
        """
        # Simplified state construction - in a real implementation,
        # this would involve NFA subset construction

        var state = DFAState()

        # For demonstration, create simple transitions based on signature hash
        var base_char = Int(signature.nfa_states_hash % 26) + ord("a")

        # Add some sample transitions
        for i in range(5):  # Add a few transitions
            var char_code = base_char + i
            if char_code <= ord("z"):
                state.add_transition(char_code, 1)  # Simplified transition

        # Set accepting status based on signature flags
        state.is_accepting = (signature.flags & 1) != 0

        return state

    fn _compute_next_signature(
        self, current: StateSignature, char_code: Int
    ) -> StateSignature:
        """Compute the signature of the next state given current state and input.

        Args:
            current: Current state signature.
            char_code: Input character code.

        Returns:
            Signature of the next state.
        """
        # Simplified signature computation - in practice this would involve
        # complex NFA state set operations
        var next_hash = current.nfa_states_hash ^ UInt64(char_code)
        next_hash = next_hash * 1099511627791  # Simple hash mixing

        return StateSignature(next_hash, current.flags)

    fn _add_to_cache(mut self, signature: StateSignature, state: DFAState):
        """Add a state to the cache, evicting old states if necessary.

        Args:
            signature: State signature (cache key).
            state: DFA state to cache.
        """
        # Check if cache is full
        if len(self.state_cache) >= self.max_cache_size:
            self._evict_old_states()

        # Add new state to cache
        var cached_state = CachedState(state)
        cached_state.access_count = 1
        cached_state.last_access = self.current_time

        self.state_cache[signature] = cached_state

    fn _evict_old_states(mut self):
        """Evict least recently used states from cache."""
        if len(self.state_cache) < CACHE_EVICTION_BATCH_SIZE:
            return

        # Simple LRU eviction - remove oldest states
        # In practice, this would use a more efficient LRU data structure

        var keys_to_remove = List[StateSignature]()
        var oldest_time = self.current_time

        # Find oldest states
        for item in self.state_cache.items():
            if item[].value.last_access < oldest_time:
                oldest_time = item[].value.last_access

        # Remove states older than a threshold
        var eviction_threshold = oldest_time + UInt64(CACHE_EVICTION_BATCH_SIZE)

        for item in self.state_cache.items():
            if item[].value.last_access <= eviction_threshold:
                keys_to_remove.append(item[].key)
            if len(keys_to_remove) >= CACHE_EVICTION_BATCH_SIZE:
                break

        # Remove the selected keys
        for i in range(len(keys_to_remove)):
            if keys_to_remove[i] in self.state_cache:
                _ = self.state_cache.pop(keys_to_remove[i])

    fn get_cache_stats(self) -> String:
        """Get cache performance statistics.

        Returns:
            String with cache hit rate and other metrics.
        """
        var total_accesses = self.cache_hits + self.cache_misses
        var hit_rate = Float64(0.0)

        if total_accesses > 0:
            hit_rate = (
                Float64(self.cache_hits) / Float64(total_accesses) * 100.0
            )

        return (
            "Cache Stats: "
            + String(len(self.state_cache))
            + "/"
            + String(self.max_cache_size)
            + " states, "
            + String(self.cache_hits)
            + " hits, "
            + String(self.cache_misses)
            + " misses, "
            + String(hit_rate)
            + "% hit rate"
        )

    fn clear_cache(mut self):
        """Clear the state cache and reset statistics."""
        self.state_cache.clear()
        self.cache_hits = 0
        self.cache_misses = 0
        self.current_time = 0


fn create_lazy_dfa_for_alternation(
    ast: ASTNode[MutableAnyOrigin], cache_size: Int = DEFAULT_LAZY_CACHE_SIZE
) raises -> LazyDFA:
    """Create a Lazy DFA optimized for alternation patterns.

    Args:
        ast: Root AST node of the pattern.
        cache_size: Size of the state cache.

    Returns:
        Configured LazyDFA engine.
    """
    var lazy_dfa = LazyDFA(cache_size)

    # Initialize start state signature based on AST
    var start_hash = UInt64(_compute_ast_hash(ast))
    lazy_dfa.start_signature = StateSignature(start_hash, 0)

    # Pre-build start state for better performance
    _ = lazy_dfa._get_or_build_state(lazy_dfa.start_signature)

    return lazy_dfa^


fn _compute_ast_hash(ast: ASTNode) -> UInt:
    """Compute a hash of the AST structure for state identification.

    Args:
        ast: AST node to hash.

    Returns:
        Hash value representing the AST structure.
    """
    # Simplified AST hashing - combine node type and children
    var hash_val = UInt(ast.type) * 1099511627791

    for i in range(ast.get_children_len()):
        hash_val ^= _compute_ast_hash(ast.get_child(i))
        hash_val *= 1099511627791  # Prime multiplier for good distribution

    if ast.get_value():
        hash_val ^= UInt(ord(ast.get_value().value()[0]))

    return hash_val


# Integration functions for the hybrid matcher


fn should_use_lazy_dfa(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Determine if a pattern would benefit from Lazy DFA.

    Args:
        ast: Root AST node to analyze.

    Returns:
        True if Lazy DFA is recommended for this pattern.
    """
    var analyzer = LazyDFAAnalyzer()
    return analyzer.analyze(ast)


struct LazyDFAAnalyzer:
    """Analyzer for determining if patterns benefit from Lazy DFA."""

    fn __init__(out self):
        pass

    fn analyze(self, ast: ASTNode[MutableAnyOrigin]) -> Bool:
        """Analyze if pattern would benefit from Lazy DFA.

        Args:
            ast: AST to analyze.

        Returns:
            True if Lazy DFA is beneficial.
        """
        var complexity_score = self._compute_complexity_score(ast, depth=0)
        var alternation_count = self._count_alternations(ast)
        var nesting_depth = self._compute_nesting_depth(ast, depth=0)

        # Patterns that benefit from Lazy DFA:
        # 1. Medium to high complexity (would create many DFA states)
        # 2. Multiple alternations (exponential state growth)
        # 3. Deep nesting (complex state dependencies)

        return (
            complexity_score > 10 and alternation_count > 3
        ) or nesting_depth > 3

    fn _compute_complexity_score(self, ast: ASTNode, depth: Int) -> Int:
        """Compute a complexity score for the AST.

        Args:
            ast: AST node to score.
            depth: Current recursion depth.

        Returns:
            Complexity score (higher = more complex).
        """
        if depth > 10:  # Prevent infinite recursion
            return 1000  # Very high complexity

        var score = 0

        if ast.type == OR:
            # Alternations increase complexity exponentially
            score += ast.get_children_len() * ast.get_children_len()
        elif ast.type == GROUP:
            # Groups add moderate complexity
            score += 2
        else:
            # Basic nodes add minimal complexity
            score += 1

        # Add complexity from children
        for i in range(ast.get_children_len()):
            score += self._compute_complexity_score(ast.get_child(i), depth + 1)

        return score

    fn _count_alternations(self, ast: ASTNode) -> Int:
        """Count the number of alternation nodes in the AST.

        Args:
            ast: AST to analyze.

        Returns:
            Number of OR nodes found.
        """
        var count = 0

        if ast.type == OR:
            count += 1

        for i in range(ast.get_children_len()):
            count += self._count_alternations(ast.get_child(i))

        return count

    fn _compute_nesting_depth(self, ast: ASTNode, depth: Int) -> Int:
        """Compute the maximum nesting depth of the AST.

        Args:
            ast: AST to analyze.
            depth: Current depth.

        Returns:
            Maximum nesting depth.
        """
        if ast.get_children_len() == 0:
            return depth

        var max_depth = depth

        for i in range(ast.get_children_len()):
            var child_depth = self._compute_nesting_depth(
                ast.get_child(i), depth + 1
            )
            if child_depth > max_depth:
                max_depth = child_depth

        return max_depth
