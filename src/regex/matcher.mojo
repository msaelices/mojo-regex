"""
Regex matcher traits and hybrid architecture for optimal performance.

This module provides the unified interface for different regex matching engines
and implements the hybrid routing system that selects the optimal engine based
on pattern complexity.
"""
from memory import UnsafePointer
from time import monotonic
from sys.ffi import _Global

from regex.ast import ASTNode
from regex.matching import Match
from regex.nfa import NFAEngine
from regex.dfa import DFAEngine, compile_simple_pattern
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

    fn __init__(
        out self,
        best_literal: Optional[String],
        has_anchors: Bool,
        is_exact_match: Bool,
    ):
        """Initialize with extracted literal info."""
        self.best_literal = best_literal
        self.has_anchors = has_anchors
        self.is_exact_match = is_exact_match

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.best_literal = other.best_literal
        self.has_anchors = other.has_anchors
        self.is_exact_match = other.is_exact_match

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.best_literal = other.best_literal^
        self.has_anchors = other.has_anchors
        self.is_exact_match = other.is_exact_match

    fn get_best_required_literal(self) -> Optional[String]:
        """Get the best required literal for matching."""
        return self.best_literal


fn create_optimized_prefilter(
    literal_info: OptimizedLiteralInfo,
) -> Optional[MemchrPrefilter]:
    """Create optimized prefilter using the better literal selection."""
    if literal_info.best_literal:
        var literal = literal_info.best_literal.value()
        # Only use literals that are long enough to be effective
        if len(literal) >= 2:
            return MemchrPrefilter(literal, False)
    return None


fn check_ast_for_anchors(ast: ASTNode[MutableAnyOrigin]) -> Bool:
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

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match in text starting from the given position.

        Args:
            text: Input text to search.
            start: Starting position in text (default 0).

        Returns:
            Optional Match if found, None otherwise.
        """
        ...

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all non-overlapping matches in text.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        ...


struct DFAMatcher(Copyable, Movable, RegexMatcher):
    """High-performance DFA-based matcher for simple patterns."""

    var engine: DFAEngine
    """The underlying DFA engine for pattern matching."""

    fn __init__(out self, owned ast: ASTNode[MutableAnyOrigin]) raises:
        """Initialize DFA matcher by compiling the AST.

        Args:
            ast: AST representing the regex pattern.
        """
        self.engine = compile_simple_pattern(ast)

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.engine = other.engine

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.engine = other.engine^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.engine.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.engine.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches using DFA execution."""
        return self.engine.match_all(text)


struct NFAMatcher(Copyable, Movable, RegexMatcher):
    """NFA-based matcher using the existing regex engine."""

    var engine: NFAEngine
    """The underlying NFA engine for pattern matching."""
    var ast: ASTNode[MutableAnyOrigin]
    """The parsed AST representation of the regex pattern."""

    fn __init__(out self, ast: ASTNode[MutableAnyOrigin], pattern: String):
        """Initialize NFA matcher with the existing engine.

        Args:
            ast: AST representing the regex pattern.
            pattern: Original pattern string.
        """
        self.engine = NFAEngine(pattern)
        self.ast = ast

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.engine = other.engine
        self.ast = other.ast

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.engine = other.engine^
        self.ast = other.ast^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using NFA execution."""
        return self.engine.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.engine.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches using NFA execution."""
        return self.engine.match_all(text)


fn _is_wildcard_match_any(pattern: String) -> Bool:
    """Check if pattern is exactly .* which matches any string.

    Args:
        pattern: The regex pattern string.

    Returns:
        True if pattern is exactly .* (dot star - match any character zero or more times).
    """
    return pattern == ".*"


fn _is_simple_pattern_skip_prefilter(pattern: String) -> Bool:
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
    var has_char_classes = False
    var has_anchors = False
    var has_wildcards = False

    for i in range(pattern_len):
        var c = pattern[i]
        if c == "*" or c == "+" or c == "?":
            has_quantifiers = True
        elif c == "|":
            has_alternation = True
        elif c == "[" or c == "]":
            has_char_classes = True
        elif c == "^" and i == 0:
            has_anchors = True
        elif c == "$" and i == pattern_len - 1:
            has_anchors = True
        elif c == ".":
            has_wildcards = True

    # Patterns likely to yield poor prefilters (mostly single-char literals):

    # 1. Simple quantifiers on single characters (a*, a+, [0-9]+)
    #    These rarely have multi-char literals that are required
    if has_quantifiers and not has_alternation and not has_wildcards:
        # Patterns like "a*", "a+", "[0-9]+" typically yield no useful literals
        return True

    # 2. Simple alternations of single characters (a|b|c)
    #    These yield only single-char literals which aren't very selective
    if has_alternation and pattern_len <= 8 and not has_wildcards:
        # Short alternation patterns like "a|b|c" yield single-char literals
        var alternation_chars = 0
        for i in range(pattern_len):
            if pattern[i] == "|":
                alternation_chars += 1
        # If it's mostly single chars separated by |, skip
        if (
            alternation_chars >= pattern_len // 3
        ):  # Lots of | relative to length
            return True

    # 3. Simple anchored patterns
    if has_anchors and pattern_len <= 8:
        return True

    # Patterns likely to yield good prefilters:

    # 1. Patterns with literals mixed with wildcards (.*.domain.com, hello.*world)
    if has_wildcards and pattern_len >= 8:
        return False

    # 2. Complex alternations that might have common prefixes
    if has_alternation and pattern_len >= 10:
        return False

    # 3. Longer patterns are more likely to have useful literals
    if pattern_len >= 12:
        return False

    # Default: skip analysis for patterns that don't match good prefilter criteria
    return True


struct HybridMatcher(Copyable, Movable, RegexMatcher):
    """Intelligent matcher that routes to optimal engine based on pattern complexity.
    """

    var dfa_matcher: Optional[DFAMatcher]
    """Optional DFA matcher for simple patterns."""
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

    fn __init__(out self, pattern: String) raises:
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
            self.dfa_matcher = None
            # Create minimal NFA matcher (required field, but won't be used)
            var dummy_ast = parse(
                "a"
            )  # Simple dummy pattern for required initialization
            self.nfa_matcher = NFAMatcher(dummy_ast, "a")
            return

        var ast = parse(pattern)

        # Early optimization: Skip prefilter analysis for very simple patterns
        # that are unlikely to benefit from the overhead
        var should_analyze_prefilter = not _is_simple_pattern_skip_prefilter(
            pattern
        )

        if should_analyze_prefilter:
            # Extract literal information using optimized implementation
            # Use MutableAnyOrigin since that's what the AST has
            var literal_set = extract_literals(ast)
            var has_anchors = check_ast_for_anchors(ast)

            # Get the best literal from the optimized selection
            var best_literal_opt: Optional[String] = None
            var is_exact = False

            var best_literal_info = literal_set.get_best_literal()
            if best_literal_info:
                var literal = best_literal_info.value().get_literal()
                if len(literal) > 0:
                    best_literal_opt = literal
                    # Simple heuristic: if we have a required literal and no complex regex constructs
                    is_exact = (
                        best_literal_info.value().is_required
                        and has_literal_prefix(ast)
                        and not has_anchors
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

        # Analyze pattern complexity
        var analyzer = PatternAnalyzer()
        self.complexity = analyzer.classify(ast)

        # Always create NFA matcher as fallback
        self.nfa_matcher = NFAMatcher(ast, pattern)

        # Create DFA matcher if pattern is simple enough
        if self.complexity.value == PatternComplexity.SIMPLE:
            try:
                self.dfa_matcher = DFAMatcher(ast)
            except:
                # DFA compilation failed, fall back to NFA only
                self.dfa_matcher = None
        else:
            self.dfa_matcher = None

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.dfa_matcher = other.dfa_matcher
        self.nfa_matcher = other.nfa_matcher
        self.complexity = other.complexity
        self.prefilter = other.prefilter
        self.literal_info = other.literal_info
        self.is_exact_literal = other.is_exact_literal
        self.is_wildcard_match_any = other.is_wildcard_match_any

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.dfa_matcher = other.dfa_matcher^
        self.nfa_matcher = other.nfa_matcher^
        self.complexity = other.complexity
        self.prefilter = other.prefilter^
        self.literal_info = other.literal_info^
        self.is_exact_literal = other.is_exact_literal
        self.is_wildcard_match_any = other.is_wildcard_match_any

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using optimal engine. This equivalent to re.match in Python.
        """
        # Fast path: Wildcard match any (.* pattern) always matches from start to end
        if self.is_wildcard_match_any:
            if start <= len(text):
                return Match(0, start, len(text), text)
            else:
                return None
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            # Use high-performance DFA for simple patterns
            return self.dfa_matcher.value().match_first(text, start)
        else:
            # Fall back to NFA for complex patterns
            return self.nfa_matcher.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
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
                return self.dfa_matcher.value().match_next(text, search_start)
            else:
                return self.nfa_matcher.match_next(text, search_start)

        # Standard path: Regular matching without prefilters
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            return self.dfa_matcher.value().match_next(text, start)
        else:
            return self.nfa_matcher.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches using optimal engine."""
        # Fast path: Wildcard match any (.* pattern) matches entire text once
        if self.is_wildcard_match_any:
            var matches = List[Match, hint_trivial_type=True]()
            if len(text) >= 0:  # .* matches even empty strings
                matches.append(Match(0, 0, len(text), text))
            return matches^
        # Fast path: Exact literal patterns without anchors
        if self.is_exact_literal and not self.literal_info.has_anchors:
            var matches = List[Match, hint_trivial_type=True]()
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
            return self.dfa_matcher.value().match_all(text)
        else:
            return self.nfa_matcher.match_all(text)

    fn get_engine_type(self) -> String:
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

    fn get_complexity(self) -> PatternComplexity:
        """Get the analyzed complexity of the pattern.

        Returns:
            PatternComplexity classification.
        """
        return self.complexity


struct CompiledRegex(Copyable, Movable):
    """High-level compiled regex object with caching and optimization."""

    var matcher: HybridMatcher
    """The hybrid matcher instance for this compiled regex."""
    var pattern: String
    """The original regex pattern string."""
    var compiled_at: Int
    """Timestamp when the regex was compiled, used for cache management."""

    fn __init__(out self, pattern: String) raises:
        """Compile a regex pattern with automatic optimization.

        Args:
            pattern: Regex pattern string.
        """
        self.pattern = pattern
        self.matcher = HybridMatcher(pattern)
        self.compiled_at = monotonic()

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.matcher = other.matcher^
        self.pattern = other.pattern^
        self.compiled_at = other.compiled_at

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match in text. This is equivalent to re.match in Python.

        Args:
            text: Input text to search.
            start: Starting position (default 0).

        Returns:
            Optional Match if found.
        """
        return self.matcher.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match in text. This is equivalent to re.search in Python.

        Args:
            text: Input text to search.
            start: Starting position (default 0).

        Returns:
            Optional Match if found.
        """
        return self.matcher.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches in text.

        Args:
            text: Input text to search.

        Returns:
            List of all matches found.
        """
        return self.matcher.match_all(text)

    fn test(self, text: String) -> Bool:
        """Test if pattern matches anywhere in text.

        Args:
            text: Input text to test.

        Returns:
            True if pattern matches, False otherwise.
        """
        var result = self.match_next(text)
        return result.__bool__()

    fn get_stats(self) -> String:
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


# TODO: Disable cache for errors found while running tests:
#  - Attempted to free corrupted pointer
#  - Possible double free detected
# Global pattern cache for improved performance
alias RegexCache = Dict[String, CompiledRegex]

alias _CACHE_GLOBAL = _Global["RegexCache", RegexCache, _init_regex_cache]


fn _init_regex_cache() -> RegexCache:
    """Initialize the global regex cache."""
    return RegexCache()


fn _get_regex_cache() -> UnsafePointer[RegexCache]:
    """Returns an pointer to the global regex cache."""

    var ptr = _CACHE_GLOBAL.get_or_create_ptr()
    return ptr


fn compile_regex(pattern: String) raises -> CompiledRegex:
    """Compile a regex pattern with caching for repeated use.

    Args:
        pattern: Regex pattern string.

    Returns:
        Compiled regex object ready for matching.
    """
    regex_cache_ptr = _get_regex_cache()
    var compiled: CompiledRegex

    if pattern in regex_cache_ptr[]:
        # Return cached compiled regex if available
        compiled = regex_cache_ptr[][pattern]
        return compiled
    else:
        # Not in cache, compile new regex
        compiled = CompiledRegex(pattern)

    # Add to cache (TODO: implement LRU eviction)
    regex_cache_ptr[][pattern] = compiled

    return compiled


fn clear_regex_cache():
    """Clear the compiled regex cache."""
    regex_cache_ptr = _get_regex_cache()
    regex_cache_ptr[].clear()


# High-level convenience functions that match Python's re module interface
fn search(pattern: String, text: String) raises -> Optional[Match]:
    """Search for pattern in text (equivalent to re.search in Python).

    Args:
        pattern: Regex pattern string.
        text: Text to search in.

    Returns:
        Optional Match if found.
    """
    var compiled = compile_regex(pattern)
    # search() should find a match anywhere, not just at the beginning
    # so we use match_next instead of match_first
    return compiled.match_next(text)


fn findall(
    pattern: String, text: String
) raises -> List[Match, hint_trivial_type=True]:
    """Find all matches of pattern in text (equivalent to re.findall in Python).

    Args:
        pattern: Regex pattern string.
        text: Text to search in.

    Returns:
        List of all matches found.
    """
    var compiled = compile_regex(pattern)
    return compiled.match_all(text)


fn match_first(pattern: String, text: String) raises -> Optional[Match]:
    """Match pattern at beginning of text (equivalent to re.match in Python).

    Args:
        pattern: Regex pattern string.
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
