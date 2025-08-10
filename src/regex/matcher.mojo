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


struct DFAMatcher[regex_orig: MutableOrigin](Copyable, Movable, RegexMatcher):
    """High-performance DFA-based matcher for simple patterns."""

    var engine: DFAEngine[regex_orig]
    """The underlying DFA engine for pattern matching."""

    fn __init__(
        out self, owned ast: ASTNode[ImmutableAnyOrigin], ref pattern: String
    ) raises:
        """Initialize DFA matcher by compiling the AST.

        Args:
            ast: AST representing the regex pattern.
        """
        self.engine = compile_simple_pattern[ImmutableAnyOrigin](ast, pattern)

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


struct HybridMatcher[regex_orig: MutableOrigin](
    Copyable, Movable, RegexMatcher
):
    """Intelligent matcher that routes to optimal engine based on pattern complexity.
    """

    var dfa_matcher: Optional[DFAMatcher[regex_orig]]
    """Optional DFA matcher for simple patterns."""
    var nfa_matcher: NFAMatcher
    """NFA matcher as fallback for complex patterns."""
    var complexity: PatternComplexity
    """Analyzed complexity level of the regex pattern."""

    fn __init__(out self, ref [regex_orig]pattern: String) raises:
        """Initialize hybrid matcher by analyzing pattern and creating appropriate engines.

        Args:
            pattern: Regex pattern string to compile.
        """
        var ast = parse(pattern)

        # Analyze pattern complexity
        var analyzer = PatternAnalyzer()
        self.complexity = analyzer.classify(ast)

        # Always create NFA matcher as fallback
        self.nfa_matcher = NFAMatcher(ast, pattern)

        # Create DFA matcher if pattern is simple enough
        if self.complexity.value == PatternComplexity.SIMPLE:
            try:
                self.dfa_matcher = DFAMatcher[regex_orig](ast, pattern)
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

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.dfa_matcher = other.dfa_matcher^
        self.nfa_matcher = other.nfa_matcher^
        self.complexity = other.complexity

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
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            # Use high-performance DFA for simple patterns
            return self.dfa_matcher.value().match_next(text, start)
        else:
            # Fall back to NFA for complex patterns
            return self.nfa_matcher.match_next(text, start)

    fn match_all(
        self, text: String
    ) raises -> List[Match, hint_trivial_type=True]:
        """Find all matches using optimal engine."""
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            # Use high-performance DFA for simple patterns
            return self.dfa_matcher.value().match_all(text)
        else:
            # Fall back to NFA for complex patterns
            return self.nfa_matcher.match_all(text)

    fn get_engine_type(self) -> String:
        """Get the type of engine being used (for debugging/profiling).

        Returns:
            String indicating which engine is active ("DFA", "NFA", or "Hybrid").
        """
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            return "DFA"
        else:
            return "NFA"

    fn get_complexity(self) -> PatternComplexity:
        """Get the analyzed complexity of the pattern.

        Returns:
            PatternComplexity classification.
        """
        return self.complexity


alias CompiledRegex = CompiledRegexImpl[MutableAnyOrigin]


struct CompiledRegexImpl[regex_orig: MutableOrigin](Copyable, Movable):
    """High-level compiled regex object with caching and optimization."""

    var matcher: HybridMatcher[regex_orig]
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
        self.matcher = HybridMatcher[regex_orig](self.pattern)
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
