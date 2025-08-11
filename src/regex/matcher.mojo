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
    LiteralExtractor,
    LiteralInfo,
    MemchrPrefilter,
    PrefilterMatcher,
    create_prefilter,
)


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


fn _is_simple_anchor_only(pattern: String) -> Bool:
    """Check if pattern is a simple anchor-only pattern that won't benefit from prefilters.
    
    Args:
        pattern: The regex pattern string.
        
    Returns:
        True if this is a simple anchored pattern like '^a', 'a$', '^a$'.
    """
    # Patterns starting with ^ or ending with $ that are very short
    var has_start_anchor = pattern.startswith("^")
    var has_end_anchor = pattern.endswith("$")
    
    if has_start_anchor or has_end_anchor:
        # For anchored patterns, check if the content is very simple
        var content_start = 1 if has_start_anchor else 0
        var content_end = len(pattern) - (1 if has_end_anchor else 0)
        var content_length = content_end - content_start
        
        # Very short anchored patterns (like "^a", "a$", "^a$") won't benefit from prefilters
        return content_length <= 3
    
    return False


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
    var literal_info: LiteralInfo
    """Extracted literal information for optimization."""
    var is_exact_literal: Bool
    """True if pattern matches only exact literals (can bypass regex entirely)."""

    fn __init__(out self, pattern: String) raises:
        """Initialize hybrid matcher by analyzing pattern and creating appropriate engines.

        Args:
            pattern: Regex pattern string to compile.
        """
        var ast = parse(pattern)

        # Early optimization: Skip prefilter analysis for very simple patterns
        # that are unlikely to benefit (short literals, pure anchors)
        var should_analyze_prefilter = len(pattern) > 2 and not _is_simple_anchor_only(pattern)
        
        if should_analyze_prefilter:
            # Extract literal information for prefilter optimization
            var literal_extractor = LiteralExtractor()
            self.literal_info = literal_extractor.extract(ast)

            # Check if this is an exact literal match that can bypass regex entirely
            self.is_exact_literal = self.literal_info.is_exact_match

            # Create prefilter if beneficial
            self.prefilter = create_prefilter(self.literal_info)
        else:
            # Initialize with empty info for simple patterns
            self.literal_info = LiteralInfo()
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

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.dfa_matcher = other.dfa_matcher^
        self.nfa_matcher = other.nfa_matcher^
        self.complexity = other.complexity
        self.prefilter = other.prefilter^
        self.literal_info = other.literal_info^
        self.is_exact_literal = other.is_exact_literal


    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using optimal engine. This equivalent to re.match in Python.
        """
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
        # Fast path: Exact literal bypass (only for non-anchored patterns)
        if self.is_exact_literal and not self.literal_info.has_anchors:
            var best_literal = self.literal_info.get_best_required_literal()
            if best_literal:
                var literal = best_literal.value()
                var pos = text.find(literal, start)
                if pos != -1:
                    return Match(0, pos, pos + len(literal), text)
                return None

        # Prefilter path: Use literal scanning for candidates (non-anchored only)
        if self.prefilter and not self.literal_info.has_anchors:
            var candidate_pos = self.prefilter.value().find_first_candidate(text, start)
            if not candidate_pos:
                return None  # No candidates found
            
            var search_start = candidate_pos.value()
            # Use appropriate engine for the filtered position
            if self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE:
                return self.dfa_matcher.value().match_next(text, search_start)
            else:
                return self.nfa_matcher.match_next(text, search_start)

        # Standard path: Regular matching without prefilters
        if self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE:
            return self.dfa_matcher.value().match_next(text, start)
        else:
            return self.nfa_matcher.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches using optimal engine."""
        # Fast path: Exact literal patterns without anchors
        if self.is_exact_literal and not self.literal_info.has_anchors:
            var matches = List[Match, hint_trivial_type=True]()
            var best_literal = self.literal_info.get_best_required_literal()
            if best_literal:
                var literal = best_literal.value()
                var start = 0
                while start <= len(text) - len(literal):
                    var pos = text.find(literal, start)
                    if pos == -1:
                        break
                    matches.append(Match(0, pos, pos + len(literal), text))
                    start = pos + 1  # Move past this match for overlapping search
            return matches^

        # Prefilter path: Use candidate positions (non-anchored only)
        if self.prefilter and not self.literal_info.has_anchors:
            var matches = List[Match, hint_trivial_type=True]()
            var candidates = self.prefilter.value().find_candidates(text)

            for i in range(len(candidates)):
                var candidate_pos = candidates[i]
                var match_result: Optional[Match]

                if self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE:
                    match_result = self.dfa_matcher.value().match_next(text, candidate_pos)
                else:
                    match_result = self.nfa_matcher.match_next(text, candidate_pos)

                if match_result:
                    matches.append(match_result.value())

            return matches^

        # Standard path: Use regular engine matching
        if self.dfa_matcher and self.complexity.value == PatternComplexity.SIMPLE:
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
