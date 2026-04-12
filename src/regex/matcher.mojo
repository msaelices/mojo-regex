"""
Regex matcher traits and hybrid architecture for optimal performance.

This module provides the unified interface for different regex matching engines
and implements the hybrid routing system that selects the optimal engine based
on pattern complexity.
"""
from std.hashlib import hash
from std.memory import UnsafePointer, alloc
from std.os import abort
from std.ffi import _Global
from std.time import monotonic

from regex.aliases import ImmSlice
from regex.ast import ASTNode
from regex.matching import Match, MatchList
from regex.nfa import NFAEngine
from regex.dfa import DFAEngine, compile_dfa_pattern
from regex.pikevm import compile_ast, PikeVMEngine, LazyDFA
from regex.optimizer import PatternAnalyzer, PatternComplexity
from regex.parser import parse
from regex.prefilter import (
    MemchrPrefilter,
    PrefilterMatcher,
)

from regex.literal_optimizer import (
    extract_literals,
    LiteralSet,
    has_literal_prefix,
)


# Adapter struct to maintain compatibility while using optimized literal_optimizer
struct OptimizedLiteralInfo(Copyable, Movable):
    """Optimized literal info that wraps literal extraction results for better performance.
    """

    var best_literal: Optional[String]
    """Best literal for prefiltering, extracted once and cached."""
    var has_anchors: Bool
    """True if pattern has start or end anchors."""
    var is_exact_match: Bool
    """True if pattern matches only exact literals."""

    def __init__(
        out self,
        best_literal: Optional[String],
        has_anchors: Bool,
        is_exact_match: Bool,
    ):
        """Initialize with extracted literal info."""
        self.best_literal = best_literal
        self.has_anchors = has_anchors
        self.is_exact_match = is_exact_match

    def __copyinit__(out self, copy: Self):
        """Copy constructor."""
        self.best_literal = copy.best_literal
        self.has_anchors = copy.has_anchors
        self.is_exact_match = copy.is_exact_match

    def __moveinit__(out self, deinit take: Self):
        """Move constructor."""
        self.best_literal = take.best_literal^
        self.has_anchors = take.has_anchors
        self.is_exact_match = take.is_exact_match

    def get_best_required_literal(self) -> Optional[String]:
        """Get the best required literal for matching."""
        return self.best_literal


def create_optimized_prefilter(
    literal_info: OptimizedLiteralInfo,
) -> Optional[MemchrPrefilter]:
    """Create optimized prefilter using the better literal selection."""
    if literal_info.best_literal:
        var literal = literal_info.best_literal.value()
        # Only use literals that are long enough to be effective
        if len(literal) >= 2:
            return MemchrPrefilter(literal, False)
    return None


def check_ast_for_anchors(ast: ASTNode[MutAnyOrigin]) -> Bool:
    """Check if AST contains start or end anchors."""
    from regex.ast import START, END, RE, GROUP

    if ast.type == START or ast.type == END:
        return True
    elif ast.type == GROUP or ast.type == RE:
        for i in range(ast.get_children_len()):
            if check_ast_for_anchors(ast.get_child(i)):
                return True
    return False


trait RegexMatcher:
    """Interface for different regex matching engines."""

    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find the first match in text starting from the given position.

        Args:
            text: Input text to search.
            start: Starting position in text (default 0).

        Returns:
            Optional Match if found, None otherwise.
        """
        ...

    def match_all(self, text: ImmSlice) raises -> MatchList:
        """Find all non-overlapping matches in text.

        Args:
            text: Input text to search.

        Returns:
            MatchList container with all matches found.
        """
        ...


struct DFAMatcher(Copyable, Movable, RegexMatcher):
    """High-performance DFA-based matcher for simple patterns."""

    var engine_ptr: UnsafePointer[DFAEngine, MutAnyOrigin]
    """The underlying DFA engine for pattern matching."""

    def __init__(out self):
        """Default constructor for empty DFA matcher."""
        self.engine_ptr = UnsafePointer[DFAEngine, MutAnyOrigin]()

    def __init__(
        out self, var ast: ASTNode[MutAnyOrigin], pattern: String
    ) raises:
        """Initialize DFA matcher by compiling the AST.

        Args:
            ast: AST representing the regex pattern.
            pattern: The original regex pattern string.
        """
        engine = compile_dfa_pattern(ast)
        self.engine_ptr = alloc[DFAEngine](1)
        self.engine_ptr.init_pointee_move(engine^)

    def __copyinit__(out self, copy: Self):
        """Copy constructor."""
        self.engine_ptr = copy.engine_ptr

    def __bool__(self) -> Bool:
        """Check if DFA matcher is valid (compiled)."""
        return Bool(self.engine_ptr)

    @always_inline
    def is_match(self, text: ImmSlice, start: Int = 0) -> Bool:
        """Check if pattern matches without computing boundaries."""
        return self.engine_ptr[].is_match(text, start)

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.engine_ptr[].match_first(text, start)

    @always_inline
    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.engine_ptr[].match_next(text, start)

    def match_all(self, text: ImmSlice) raises -> MatchList:
        """Find all matches using DFA execution."""
        return self.engine_ptr[].match_all(text)


struct NFAMatcher(Copyable, Movable, RegexMatcher):
    """NFA-based matcher with lazy DFA acceleration.

    Owns an optional heap-allocated `LazyDFA`. The lazy DFA is stored
    behind a nullable `UnsafePointer` rather than an `Optional[LazyDFA]`
    inline so that calling `mut self` methods on it (the lazy DFA caches
    transitions as it runs) is possible through the read-only `self` that
    the `RegexMatcher` trait demands. A null pointer means no lazy DFA is
    available; this collapses the previous `(ptr, has_dfa_bool)` pair into
    a single source of truth and avoids the dead-store-elimination pitfall
    that would fire when the bool was zeroed in `__moveinit__`.
    """

    var engine: NFAEngine
    """The underlying NFA engine for pattern matching."""
    var ast: ASTNode[MutAnyOrigin]
    """The parsed AST representation of the regex pattern."""
    var _lazy_dfa_ptr: UnsafePointer[LazyDFA, MutAnyOrigin]
    """Heap-allocated lazy DFA. Null when the pattern is not eligible for
    lazy-DFA acceleration (e.g., PikeVM program exceeds MAX_STATES)."""

    def __init__(out self, ast: ASTNode[MutAnyOrigin], pattern: String):
        """Initialize NFA matcher with optional lazy DFA."""
        self.engine = NFAEngine(pattern)
        self.ast = ast
        var vm = PikeVMEngine(compile_ast(ast))
        if vm.is_supported():
            self._lazy_dfa_ptr = alloc[LazyDFA](1)
            # `init_pointee_move` constructs into uninitialized memory.
            # The previous `self._lazy_dfa_ptr[] = LazyDFA(vm^)` form ran
            # move-assignment into garbage storage, which was the source
            # of the flaky double-free at process exit (issue #97).
            self._lazy_dfa_ptr.init_pointee_move(LazyDFA(vm^))
        else:
            self._lazy_dfa_ptr = UnsafePointer[LazyDFA, MutAnyOrigin]()

    def __copyinit__(out self, copy: Self):
        """Copy constructor. Deep-copies the lazy DFA so each matcher
        owns an independent cache."""
        self.engine = copy.engine.copy()
        self.ast = copy.ast
        if copy._lazy_dfa_ptr:
            self._lazy_dfa_ptr = alloc[LazyDFA](1)
            self._lazy_dfa_ptr.init_pointee_move(copy._lazy_dfa_ptr[].copy())
        else:
            self._lazy_dfa_ptr = UnsafePointer[LazyDFA, MutAnyOrigin]()

    def __moveinit__(out self, deinit take: Self):
        """Move constructor. Transfers ownership of the heap-allocated
        lazy DFA from `take` to `self`. No need to clear `take`'s pointer:
        Mojo's `deinit take` semantics guarantee `take.__del__` is not
        called after this function returns (the compiler will warn if a
        field write is interpreted as a dead store, confirming `take` is
        fully consumed)."""
        self.engine = take.engine^
        self.ast = take.ast^
        self._lazy_dfa_ptr = take._lazy_dfa_ptr

    def __del__(deinit self):
        """Free the heap-allocated lazy DFA if we still own one."""
        if self._lazy_dfa_ptr:
            self._lazy_dfa_ptr.destroy_pointee()
            self._lazy_dfa_ptr.free()

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match. Uses lazy DFA if available."""
        if self._lazy_dfa_ptr:
            return self._lazy_dfa_ptr[].match_first(text, start)
        return self.engine.match_first(text, start)

    @always_inline
    def _use_lazy_dfa_for_search(self) -> Bool:
        """Use lazy DFA when NFA has no fast paths."""
        return (
            Bool(self._lazy_dfa_ptr)
            and not self.engine.has_literal_optimization
            and not self.engine._starts_with_dotstar()
            and not self.engine._ends_with_dotstar()
        )

    @always_inline
    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Search for match."""
        if self._use_lazy_dfa_for_search():
            return self._lazy_dfa_ptr[].match_next(text, start)
        return self.engine.match_next(text, start)

    @always_inline
    def match_all(self, text: ImmSlice) raises -> MatchList:
        """Find all matches."""
        if self._use_lazy_dfa_for_search():
            return self._lazy_dfa_ptr[].match_all(text)
        return self.engine.match_all(text)


@always_inline
def _is_wildcard_match_any(pattern: String) -> Bool:
    """Check if pattern is exactly .* which matches any string.

    Args:
        pattern: The regex pattern string.

    Returns:
        True if pattern is exactly .* (dot star - match any character zero or more times).
    """
    return pattern == ".*"


def _is_simple_pattern_skip_prefilter(pattern: String) -> Bool:
    """Check if pattern is too simple to benefit from prefilter analysis.

    This function identifies patterns that are unlikely to yield useful prefilters,
    where the overhead of analysis exceeds any potential benefit.

    Args:
        pattern: The regex pattern string.

    Returns:
        True if prefilter analysis should be skipped for performance.
    """
    var pattern_len = len(pattern)

    # Skip very short patterns entirely - unlikely to yield useful prefilters
    if pattern_len <= 4:
        return True

    # Check for regex metacharacters
    var has_quantifiers = False
    var has_alternation = False
    var has_anchors = False
    var has_wildcards = False
    var has_character_classes = False

    var pattern_ptr = pattern.unsafe_ptr()
    for i in range(pattern_len):
        var c = Int(pattern_ptr[i])
        if c == ord("*") or c == ord("+") or c == ord("?"):
            has_quantifiers = True
        elif c == ord("|"):
            has_alternation = True
        elif c == ord("^") and i == 0:
            has_anchors = True
        elif c == ord("$") and i == pattern_len - 1:
            has_anchors = True
        elif c == ord("."):
            has_wildcards = True
        elif c == ord("["):
            has_character_classes = True

    # Patterns likely to yield poor prefilters (mostly single-char literals):

    # 1. Simple quantifiers on single characters (a*, a+, [0-9]+)
    #    These rarely have multi-char literals that are required
    if has_quantifiers and not has_alternation and not has_wildcards:
        # Simple quantified character classes like [0-9]+ should skip prefilter
        if has_character_classes and pattern_len <= 8:
            return True
        # Other simple quantified patterns like "a*", "a+"
        return True

    # 2. Simple alternations of single characters (a|b|c)
    #    These yield only single-char literals which aren't very selective
    if has_alternation and pattern_len <= 10 and not has_wildcards:
        # Short alternation patterns like "a|b|c" yield single-char literals
        var alternation_chars = 0
        for i in range(pattern_len):
            if Int(pattern_ptr[i]) == ord("|"):
                alternation_chars += 1
        # If it's mostly single chars separated by |, skip
        if (
            alternation_chars >= pattern_len // 3
        ):  # Lots of | relative to length
            return True

    # 3. Simple anchored patterns
    if has_anchors and pattern_len <= 10:
        return True

    # Patterns likely to yield good prefilters:

    # 1. Patterns with literals mixed with wildcards (.*.domain.com, hello.*world)
    if has_wildcards and pattern_len >= 8:
        return False

    # 2. Complex alternations that might have common prefixes
    if has_alternation and pattern_len >= 12:
        return False

    # 3. Longer patterns are more likely to have useful literals
    if pattern_len >= 15:
        return False

    # Default: skip analysis for patterns that don't match good prefilter criteria
    return True


struct HybridMatcher(Copyable, Movable, RegexMatcher):
    """Intelligent matcher that routes to optimal engine based on pattern complexity.
    """

    var dfa_matcher: DFAMatcher
    """DFA matcher for simple patterns."""
    var nfa_matcher: NFAMatcher
    """NFA matcher as fallback for complex patterns."""
    var complexity: PatternComplexity
    """Analyzed complexity level of the regex pattern."""
    var prefilter: Optional[MemchrPrefilter]
    """Optional prefilter for fast candidate identification."""
    var literal_info: OptimizedLiteralInfo
    """Extracted literal information for optimization."""
    var is_exact_literal: Bool
    """True if pattern matches only exact literals (can bypass regex entirely)."""
    var is_wildcard_match_any: Bool
    """True if pattern is exactly .* (matches any string)."""
    var use_pure_dfa: Bool
    """True if pattern should use pure DFA without SIMD integration."""

    def __init__(out self, pattern: String) raises:
        """Initialize hybrid matcher by analyzing pattern and creating appropriate engines.

        Args:
            pattern: Regex pattern string to compile.
        """
        # Early optimization: Check for wildcard match any pattern (.*)
        self.is_wildcard_match_any = _is_wildcard_match_any(pattern)

        # Fast path: Skip all expensive operations for .* pattern
        if self.is_wildcard_match_any:
            # Initialize with minimal state for .* pattern
            self.literal_info = OptimizedLiteralInfo(None, False, False)
            self.is_exact_literal = False
            self.prefilter = None
            self.complexity = PatternComplexity(PatternComplexity.SIMPLE)
            self.dfa_matcher = DFAMatcher()
            self.use_pure_dfa = False  # Special wildcard handling
            # Create minimal NFA matcher (required field, but won't be used)
            var dummy_ast = parse(
                "a"
            )  # Simple dummy pattern for required initialization
            self.nfa_matcher = NFAMatcher(dummy_ast, "a")
            return

        var ast = parse(pattern)

        # Analyze pattern complexity early
        var analyzer = PatternAnalyzer()
        self.complexity = analyzer.classify(ast)

        # Check if pattern should use pure DFA
        self.use_pure_dfa = analyzer.should_use_pure_dfa(ast)

        # Early optimization: Skip prefilter analysis for very simple patterns
        # that are unlikely to benefit from the overhead
        var should_analyze_prefilter = (
            not _is_simple_pattern_skip_prefilter(pattern)
            and not self.use_pure_dfa
        )  # Skip prefilter for pure DFA patterns

        if should_analyze_prefilter:
            # Extract literal information using optimized implementation
            # Use MutAnyOrigin since that's what the AST has
            var literal_set = extract_literals(ast)
            var has_anchors = check_ast_for_anchors(ast)

            # Get the best literal from the optimized selection
            var best_literal_opt: Optional[String] = None
            var is_exact = False

            var best_literal_info = literal_set.get_best_literal()
            if best_literal_info:
                var literal = best_literal_info.value().get_literal(literal_set)
                if len(literal) > 0:
                    best_literal_opt = literal
                    # Simple heuristic: if we have a required literal and no complex regex constructs
                    # Must also check that the pattern doesn't contain regex operators
                    var has_regex_operators = (
                        "*" in pattern
                        or "+" in pattern
                        or "?" in pattern
                        or "." in pattern
                        or "|" in pattern
                        or "(" in pattern
                        or "[" in pattern
                        or "{" in pattern
                    )
                    is_exact = (
                        best_literal_info.value().is_required
                        and has_literal_prefix(ast)
                        and not has_anchors
                        and not has_regex_operators
                    )

            self.literal_info = OptimizedLiteralInfo(
                best_literal_opt, has_anchors, is_exact
            )
            self.is_exact_literal = is_exact

            # Create prefilter if beneficial
            self.prefilter = create_optimized_prefilter(self.literal_info)
        else:
            # Initialize with empty info for simple patterns
            self.literal_info = OptimizedLiteralInfo(None, False, False)
            self.is_exact_literal = False
            self.prefilter = None

        # Always create NFA matcher as fallback
        self.nfa_matcher = NFAMatcher(ast, pattern)

        # Create DFA matcher if pattern is simple enough
        if self.complexity.value == PatternComplexity.SIMPLE:
            try:
                self.dfa_matcher = DFAMatcher(ast, pattern)
            except:
                # DFA compilation failed, fall back to NFA only
                self.dfa_matcher = DFAMatcher()
        else:
            self.dfa_matcher = DFAMatcher()

    def __copyinit__(out self, copy: Self):
        """Copy constructor."""
        self.dfa_matcher = copy.dfa_matcher.copy()
        self.nfa_matcher = copy.nfa_matcher.copy()
        self.complexity = copy.complexity
        self.prefilter = copy.prefilter.copy()
        self.literal_info = copy.literal_info.copy()
        self.is_exact_literal = copy.is_exact_literal
        self.is_wildcard_match_any = copy.is_wildcard_match_any
        self.use_pure_dfa = copy.use_pure_dfa

    def __moveinit__(out self, deinit take: Self):
        """Move constructor."""
        self.dfa_matcher = take.dfa_matcher^
        self.nfa_matcher = take.nfa_matcher^
        self.complexity = take.complexity
        self.prefilter = take.prefilter^
        self.literal_info = take.literal_info^
        self.is_exact_literal = take.is_exact_literal
        self.is_wildcard_match_any = take.is_wildcard_match_any
        self.use_pure_dfa = take.use_pure_dfa

    @always_inline
    def is_match(self, text: ImmSlice, start: Int = 0) -> Bool:
        """Check if pattern matches without computing boundaries."""
        if self.is_wildcard_match_any:
            return start <= len(text)

        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            return self.dfa_matcher.is_match(text, start)

        # NFA fallback: use full match
        return Bool(self.nfa_matcher.match_first(text, start))

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match using optimal engine. This equivalent to re.match in Python.
        """

        # Fast path: Wildcard match any (.* pattern) always matches from start to end
        if self.is_wildcard_match_any:
            if start <= len(text):
                return Match(0, start, len(text), text)
            else:
                return None

        # Prioritize DFA for SIMPLE patterns, especially pure DFA patterns
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            # Use high-performance DFA for simple patterns
            return self.dfa_matcher.match_first(text, start)
        else:
            # Fall back to NFA for complex patterns
            return self.nfa_matcher.match_first(text, start)

    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match using optimal engine. This is equivalent to re.search in Python.
        """
        # Fast path: Wildcard match any (.* pattern) always matches from start to end
        if self.is_wildcard_match_any:
            if start <= len(text):
                return Match(0, start, len(text), text)
            else:
                return None
        # Fast path: Exact literal bypass (only for non-anchored patterns)
        if self.is_exact_literal and not self.literal_info.has_anchors:
            var best_literal = self.literal_info.get_best_required_literal()
            if best_literal:
                var literal = best_literal.value()
                # Simple bounds check to avoid issues
                if start >= len(text):
                    return None
                var pos = text.find(literal, start)
                if pos != -1:
                    # Ensure we don't exceed text bounds
                    var end_pos = pos + len(literal)
                    if end_pos <= len(text):
                        return Match(0, pos, end_pos, text)
                return None

        # Prefilter path: Use literal scanning for candidates (non-anchored only)
        if self.prefilter and not self.literal_info.has_anchors:
            var candidate_pos = self.prefilter.value().find_first_candidate(
                text, start
            )
            if not candidate_pos:
                return None  # No candidates found

            var search_start = candidate_pos.value()
            # Use appropriate engine for the filtered position
            if (
                self.dfa_matcher
                and self.complexity.value == PatternComplexity.SIMPLE
            ):
                return self.dfa_matcher.match_next(text, search_start)
            else:
                return self.nfa_matcher.match_next(text, search_start)

        # Standard path: Regular matching without prefilters
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            return self.dfa_matcher.match_next(text, start)
        else:
            return self.nfa_matcher.match_next(text, start)

    def match_all(self, text: ImmSlice) raises -> MatchList:
        """Find all matches using optimal engine."""
        # Fast path: Wildcard match any (.* pattern) matches entire text once
        if self.is_wildcard_match_any:
            var matches = MatchList()
            if len(text) >= 0:  # .* matches even empty strings
                matches.append(Match(0, 0, len(text), text))
            return matches^
        # Fast path: Exact literal patterns without anchors
        if self.is_exact_literal and not self.literal_info.has_anchors:
            var matches = MatchList()
            var best_literal = self.literal_info.get_best_required_literal()
            if best_literal:
                var literal = best_literal.value()
                var literal_len = len(literal)
                var text_len = len(text)

                # Bounds check to avoid issues
                if literal_len > text_len:
                    return matches^

                var start = 0
                var max_start = text_len - literal_len

                # Safe loop with explicit bounds checking
                while start <= max_start:
                    var pos = text.find(literal, start)
                    if pos == -1:
                        break
                    # Double-check bounds before creating Match
                    var end_pos = pos + literal_len
                    if end_pos <= text_len:
                        matches.append(Match(0, pos, end_pos, text))
                    # Move past this match to avoid infinite loop
                    start = pos + 1
                    # Safety check to prevent runaway loops
                    if start > max_start:
                        break
            return matches^

        # Prefilter path: Use candidate positions (non-anchored only)
        if self.prefilter and not self.literal_info.has_anchors:
            # Disabled for now to isolate performance issue
            # TODO: Fix prefilter performance issue
            pass

        # Standard path: Use regular engine matching
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            return self.dfa_matcher.match_all(text)
        else:
            return self.nfa_matcher.match_all(text)

    def get_engine_type(self) -> String:
        """Get the type of engine being used (for debugging/profiling).

        Returns:
            String indicating which engine is active with prefilter info.
        """
        var base_engine: String
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            base_engine = "DFA"
        else:
            base_engine = "NFA"

        # Add optimization information
        if self.is_exact_literal and not self.literal_info.has_anchors:
            return base_engine + "+ExactLiteral"
        elif self.prefilter and not self.literal_info.has_anchors:
            return base_engine + "+Prefilter"
        else:
            return base_engine

    def get_complexity(self) -> PatternComplexity:
        """Get the analyzed complexity of the pattern.

        Returns:
            PatternComplexity classification.
        """
        return self.complexity


struct CompiledRegex(ImplicitlyCopyable, Movable):
    """High-level compiled regex object with caching and optimization.

    Uses cached HybridMatcher instances for optimal performance. The caching approach
    avoids expensive matcher recreation on each operation while maintaining correctness
    for normal regex operations.

    Note: There is a known corruption issue that affects complex pattern sequences,
    but this occurs at a deeper level in the regex engine beyond the caching layer.
    """

    var matcher: HybridMatcher
    """The hybrid matcher instance for this compiled regex."""
    var pattern: String
    """The original regex pattern string."""
    var compiled_at: Int
    """Timestamp when the regex was compiled, used for cache management."""

    def __init__(out self, pattern: String) raises:
        """Compile a regex pattern with automatic optimization.

        Args:
            pattern: Regex pattern string.
        """
        self.pattern = pattern
        self.matcher = HybridMatcher(pattern)
        self.compiled_at = Int(monotonic())

    def __copyinit__(out self, copy: Self):
        """Copy constructor."""
        self.matcher = copy.matcher.copy()
        self.pattern = copy.pattern
        self.compiled_at = copy.compiled_at

    def __moveinit__(out self, deinit take: Self):
        """Move constructor."""
        self.matcher = take.matcher^
        self.pattern = take.pattern^
        self.compiled_at = take.compiled_at

    # @always_inline
    # fn __del__(deinit self):
    #     """Destructor to clean up resources."""
    #     call_location = __call_location()
    #     print(
    #         "CompiledRegex for pattern '",
    #         self.pattern,
    #         "' is being deleted in ",
    #         call_location,
    #     )

    @always_inline
    def match_first(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match in text. This is equivalent to re.match in Python.

        Args:
            text: Input text to search.
            start: Starting position (default 0).

        Returns:
            Optional Match if found.
        """
        return self.matcher.match_first(text, start)

    def match_next(self, text: ImmSlice, start: Int = 0) -> Optional[Match]:
        """Find first match in text. This is equivalent to re.search in Python.

        Args:
            text: Input text to search.
            start: Starting position (default 0).

        Returns:
            Optional Match if found.
        """
        return self.matcher.match_next(text, start)

    def match_all(self, text: ImmSlice) raises -> MatchList:
        """Find all matches in text.

        Args:
            text: Input text to search.

        Returns:
            MatchList container with all matches found.
        """
        return self.matcher.match_all(text)

    def test(mut self, text: ImmSlice) -> Bool:
        """Test if pattern matches anywhere in text.

        Args:
            text: Input text to test.

        Returns:
            True if pattern matches, False otherwise.
        """
        var result = self.matcher.match_next(text, 0)
        return result.__bool__()

    @always_inline
    def is_match(self, text: ImmSlice, start: Int = 0) -> Bool:
        """Check if pattern matches at the given position without computing
        match boundaries. Much faster than match_first for simple existence checks.

        Args:
            text: Input text to test.
            start: Starting position (default 0).

        Returns:
            True if pattern matches, False otherwise.
        """
        return self.matcher.is_match(text, start)

    def get_stats(self) -> String:
        """Get performance statistics and engine information.

        Returns:
            String with debugging information.
        """
        var engine_type = self.matcher.get_engine_type()
        var complexity = self.matcher.get_complexity()

        var complexity_str: String
        if complexity.value == PatternComplexity.SIMPLE:
            complexity_str = "SIMPLE"
        elif complexity.value == PatternComplexity.MEDIUM:
            complexity_str = "MEDIUM"
        else:
            complexity_str = "COMPLEX"

        return (
            "Pattern: '"
            + self.pattern
            + "', Engine: "
            + engine_type
            + ", Complexity: "
            + complexity_str
        )


# Global pattern cache for improved performance.
#
# Keyed on `hash(pattern) -> UInt64` rather than `String` so that cache
# lookups from a `StringSlice` caller do not require allocating a new
# `String` just to probe the map. On a cache hit we verify that the
# stored `CompiledRegex.pattern` byte-equals the caller's pattern, which
# handles (astronomically unlikely) 64-bit hash collisions by falling
# through to a fresh compile. See the collision analysis on issue #97.
comptime RegexCache = Dict[UInt64, CompiledRegex]

comptime _CACHE_GLOBAL = _Global["RegexCache", _init_regex_cache]


def _init_regex_cache() -> RegexCache:
    """Initialize the global regex cache."""
    return RegexCache()


def _get_regex_cache() -> UnsafePointer[RegexCache, MutAnyOrigin]:
    """Returns an pointer to the global regex cache."""
    try:
        return _CACHE_GLOBAL.get_or_create_ptr()
    except e:
        abort[prefix="ERROR:"](String(e))


def compile_regex(pattern: ImmSlice) raises -> CompiledRegex:
    """Compile a regex pattern with caching for repeated use.

    Args:
        pattern: Regex pattern.

    Returns:
        Compiled regex object ready for matching.
    """
    var regex_cache_ptr = _get_regex_cache()
    var key = hash(pattern)
    var compiled: CompiledRegex

    if key in regex_cache_ptr[]:
        compiled = regex_cache_ptr[][key]
        if compiled.pattern == pattern:
            return compiled
        # Hash collision: fall through to a fresh compile and overwrite.

    # Cache miss: allocate the pattern String once for CompiledRegex to
    # own. `get_stats` and engine construction both need a real String.
    compiled = CompiledRegex(String(pattern))
    regex_cache_ptr[][key] = compiled
    return compiled


def clear_regex_cache():
    """Clear the compiled regex cache."""
    regex_cache_ptr = _get_regex_cache()
    regex_cache_ptr[].clear()


# High-level convenience functions that match Python's re module interface
def search(pattern: ImmSlice, text: ImmSlice) raises -> Optional[Match]:
    """Search for pattern in text (equivalent to re.search in Python).

    Args:
        pattern: Regex pattern.
        text: Text to search in.

    Returns:
        Optional Match if found.
    """
    var compiled = compile_regex(pattern)
    # search() should find a match anywhere, not just at the beginning
    # so we use match_next instead of match_first
    return compiled.match_next(text)


def findall(pattern: ImmSlice, text: ImmSlice) raises -> MatchList:
    """Find all matches of pattern in text (equivalent to re.findall in Python).

    Args:
        pattern: Regex pattern.
        text: Text to search in.

    Returns:
        Matches container with all matches found.
    """
    var compiled = compile_regex(pattern)
    return compiled.match_all(text)


def match_first(pattern: ImmSlice, text: ImmSlice) raises -> Optional[Match]:
    """Match pattern at beginning of text (equivalent to re.match in Python).

    Args:
        pattern: Regex pattern.
        text: Text to match against.

    Returns:
        Optional Match if pattern matches at start of text.
    """
    var compiled = compile_regex(pattern)
    var result = compiled.match_first(text, 0)

    # Python's re.match only succeeds if match starts at position 0
    if result and result.value().start_idx == 0:
        return result
    else:
        return None


def _has_group_refs(repl: ImmSlice) -> Bool:
    """Check if repl contains \\1..\\9 backreferences."""
    var repl_ptr = repl.unsafe_ptr()
    var repl_len = len(repl)
    for i in range(repl_len - 1):
        if Int(repl_ptr[i]) == ord("\\"):
            var next_ch = Int(repl_ptr[i + 1])
            if next_ch >= ord("1") and next_ch <= ord("9"):
                return True
    return False


def _detect_fixed_width_groups(
    pattern: ImmSlice,
) -> Optional[List[Int]]:
    """Detect if pattern is a sequence of fixed-width \\d{N} capture groups
    with optional fixed-width literals/escapes between them.

    Returns a list encoding the pattern structure: positive values are
    capture group widths (in order), negative values are inter-group
    literal byte counts to skip. Example: `(\\d{3})-(\\d{4})` returns
    [3, -1, 4].

    Returns None if the pattern doesn't qualify (alternation, variable
    quantifiers, nested groups, non-\\d groups, character classes).
    """
    var p = pattern.unsafe_ptr()
    var plen = len(pattern)
    var segments = List[Int]()
    var i = 0
    var literal_run = 0  # track bytes of literal content between groups

    while i < plen:
        if Int(p[i]) == ord("("):
            # Flush any literal run
            if literal_run > 0:
                segments.append(-literal_run)
                literal_run = 0

            # Check for non-capturing (?:...)
            if i + 1 < plen and Int(p[i + 1]) == ord("?"):
                return None

            i += 1  # skip (

            # Expect \d or \d{N}
            if (
                i + 1 >= plen
                or Int(p[i]) != ord("\\")
                or Int(p[i + 1]) != ord("d")
            ):
                return None
            i += 2  # skip \d

            # Check for {N}
            if i < plen and Int(p[i]) == ord("{"):
                i += 1  # skip {
                var num_start = i
                while (
                    i < plen and Int(p[i]) >= ord("0") and Int(p[i]) <= ord("9")
                ):
                    i += 1
                if i == num_start or i >= plen or Int(p[i]) != ord("}"):
                    return None
                var width = 0
                for j in range(num_start, i):
                    width = width * 10 + (Int(p[j]) - ord("0"))
                i += 1  # skip }
                segments.append(width)
            elif i < plen and Int(p[i]) == ord(")"):
                # Bare \d: width 1
                segments.append(1)
            else:
                return None  # Variable quantifier

            # Expect closing )
            if i >= plen or Int(p[i]) != ord(")"):
                return None
            i += 1  # skip )
        elif Int(p[i]) == ord("|") or Int(p[i]) == ord("["):
            return None
        else:
            # Literal or escape between groups
            if Int(p[i]) == ord("\\") and i + 1 < plen:
                literal_run += (
                    1  # the escaped char takes 1 byte in matched text
                )
                i += 2
            else:
                literal_run += 1
                i += 1

    # Check we found at least one group
    var has_group = False
    for si in range(len(segments)):
        if segments[si] > 0:
            has_group = True
            break
    if not has_group:
        return None
    return segments^


def _interpolate_groups(
    repl: ImmSlice,
    text: ImmSlice,
    groups: List[Match],
) -> String:
    """Replace \\1..\\9 in repl with the corresponding capture group text."""
    var repl_ptr = repl.unsafe_ptr()
    var repl_len = len(repl)
    var out = String(capacity=repl_len + 32)

    # Build an indexed lookup: group_spans[N] = index into groups list
    # for group_id == N. -1 means no match. O(1) per \N reference.
    var group_idx = InlineArray[Int, 10](fill=-1)
    for gi in range(len(groups)):
        var gid = groups[gi].group_id
        if 1 <= gid <= 9:
            group_idx[gid] = gi

    var i = 0
    while i < repl_len:
        if Int(repl_ptr[i]) == ord("\\") and i + 1 < repl_len:
            var next_ch = Int(repl_ptr[i + 1])
            if next_ch >= ord("1") and next_ch <= ord("9"):
                var group_num = next_ch - ord("0")
                var idx = group_idx[group_num]
                if idx >= 0:
                    out += groups[idx].get_match_text()
                i += 2
                continue
        out += ImmSlice(ptr=repl_ptr + i, length=1)
        i += 1
    return out


@always_inline
def _interpolate_fixed_groups(
    repl: ImmSlice,
    text_ptr: UnsafePointer[Byte, ImmutAnyOrigin],
    match_start: Int,
    segments: List[Int],
) -> String:
    """Interpolate \\1..\\9 using precomputed fixed-width group offsets.

    `segments` encodes the pattern structure: positive = group width,
    negative = literal skip bytes. Group numbering is 1-based in order
    of positive segments.
    """
    var repl_ptr = repl.unsafe_ptr()
    var repl_len = len(repl)
    var out = String(capacity=repl_len + 32)

    # Precompute group start offsets and widths from segments.
    # Walk segments accumulating byte offset from match_start.
    var group_starts = InlineArray[Int, 10](fill=0)
    var group_widths = InlineArray[Int, 10](fill=0)
    var num_groups = 0
    var offset = match_start
    for si in range(len(segments)):
        var seg = segments[si]
        if seg > 0:
            # Capture group
            num_groups += 1
            group_starts[num_groups] = offset
            group_widths[num_groups] = seg
            offset += seg
        else:
            # Literal skip
            offset += -seg

    var i = 0
    while i < repl_len:
        if Int(repl_ptr[i]) == ord("\\") and i + 1 < repl_len:
            var next_ch = Int(repl_ptr[i + 1])
            if next_ch >= ord("1") and next_ch <= ord("9"):
                var group_num = next_ch - ord("0")
                if group_num <= num_groups:
                    var gs = group_starts[group_num]
                    var gw = group_widths[group_num]
                    out += ImmSlice(ptr=text_ptr + gs, length=gw)
                i += 2
                continue
        out += ImmSlice(ptr=repl_ptr + i, length=1)
        i += 1
    return out


def sub(
    pattern: ImmSlice,
    repl: ImmSlice,
    text: ImmSlice,
    count: Int = 0,
) raises -> String:
    """Replace occurrences of pattern in text with repl (equivalent to re.sub).

    If repl contains \\1..\\9 backreferences, they are replaced with the
    corresponding capture group text from each match.

    Args:
        pattern: Regex pattern to search for.
        repl: Replacement string (may contain \\1..\\9 group references).
        text: Text to search and replace in.
        count: Maximum number of replacements (0 means replace all).

    Returns:
        New string with replacements applied.
    """
    var text_len = len(text)
    if text_len == 0:
        return String(text)

    var compiled = compile_regex(pattern)
    var text_ptr = text.unsafe_ptr()
    var result = String(capacity=text_len + 64)
    var pos = 0
    var replacements = 0
    var use_groups = _has_group_refs(repl)

    if use_groups:
        # Check for fixed-width groups fast path: if all groups are \d{N},
        # we can compute group boundaries from match position + widths
        # without running the NFA at all.
        var fixed_widths = _detect_fixed_width_groups(pattern)
        if fixed_widths:
            var segments = fixed_widths.value().copy()
            # Fixed-width fast path: use optimized matcher for finding
            # matches, compute groups from offsets (no NFA needed)
            while pos <= text_len:
                var m = compiled.match_next(text, pos)
                if not m:
                    break
                var match_start = m.value().start_idx
                var match_end = m.value().end_idx

                if match_start > pos:
                    result += ImmSlice(
                        ptr=text_ptr + pos, length=match_start - pos
                    )

                result += _interpolate_fixed_groups(
                    repl, text_ptr, match_start, segments
                )
                replacements += 1

                if match_end == match_start:
                    if pos < text_len:
                        result += ImmSlice(ptr=text_ptr + pos, length=1)
                    pos = match_end + 1
                else:
                    pos = match_end

                if count > 0 and replacements >= count:
                    break
        else:
            # General group path: uses NFA engine to extract captures
            while pos <= text_len:
                var mg = (
                    compiled.matcher.nfa_matcher.engine.match_next_with_groups(
                        text, pos
                    )
                )
                if not mg[0]:
                    break
                var m = mg[0].value()

                if m.start_idx > pos:
                    result += ImmSlice(
                        ptr=text_ptr + pos, length=m.start_idx - pos
                    )

                result += _interpolate_groups(repl, text, mg[1])
                replacements += 1

                if m.end_idx == m.start_idx:
                    if pos < text_len:
                        result += ImmSlice(ptr=text_ptr + pos, length=1)
                    pos = m.end_idx + 1
                else:
                    pos = m.end_idx

                if count > 0 and replacements >= count:
                    break
    else:
        # Fast path: no group refs, use the optimized matcher chain
        while pos <= text_len:
            var m = compiled.match_next(text, pos)
            if not m:
                break
            var match_start = m.value().start_idx
            var match_end = m.value().end_idx

            if match_start > pos:
                result += ImmSlice(ptr=text_ptr + pos, length=match_start - pos)

            result += repl
            replacements += 1

            if match_end == match_start:
                if pos < text_len:
                    result += ImmSlice(ptr=text_ptr + pos, length=1)
                pos = match_end + 1
            else:
                pos = match_end

            if count > 0 and replacements >= count:
                break

    if pos < text_len:
        result += ImmSlice(ptr=text_ptr + pos, length=text_len - pos)

    return result
