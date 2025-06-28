"""
Regex matcher traits and hybrid architecture for optimal performance.

This module provides the unified interface for different regex matching engines
and implements the hybrid routing system that selects the optimal engine based
on pattern complexity.
"""

from collections import List
from regex.ast import ASTNode
from regex.engine import Match
from regex.engine import RegexEngine
from regex.dfa import DFAEngine, compile_simple_pattern
from regex.optimizer import PatternAnalyzer, PatternComplexity
from regex.parser import parse


trait RegexMatcher:
    """Interface for different regex matching engines."""

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match in text starting from the given position.

        Args:
            text: Input text to search
            start: Starting position in text (default 0)

        Returns:
            Optional Match if found, None otherwise
        """
        ...

    fn match_all(self, text: String) raises -> List[Match]:
        """Find all non-overlapping matches in text.

        Args:
            text: Input text to search

        Returns:
            List of all matches found
        """
        ...


struct DFAMatcher(Copyable, Movable, RegexMatcher):
    """High-performance DFA-based matcher for simple patterns."""

    var dfa: DFAEngine
    var pattern_string: String

    fn __init__(out self, ast: ASTNode, pattern: String) raises:
        """Initialize DFA matcher by compiling the AST.

        Args:
            ast: AST representing the regex pattern
            pattern: Original pattern string
        """
        self.pattern_string = pattern
        self.dfa = compile_simple_pattern(ast)

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.dfa = other.dfa
        self.pattern_string = other.pattern_string

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.dfa = other.dfa^
        self.pattern_string = other.pattern_string^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using DFA execution."""
        return self.dfa.match_dfa(text, start)

    fn match_all(self, text: String) raises -> List[Match]:
        """Find all matches using DFA execution."""
        return self.dfa.match_all_dfa(text)


struct NFAMatcher(Copyable, Movable, RegexMatcher):
    """NFA-based matcher using the existing regex engine."""

    var engine: RegexEngine
    var ast: ASTNode
    var pattern_string: String

    fn __init__(out self, ast: ASTNode, pattern: String):
        """Initialize NFA matcher with the existing engine.

        Args:
            ast: AST representing the regex pattern
            pattern: Original pattern string
        """
        self.engine = RegexEngine()
        self.ast = ast
        self.pattern_string = pattern

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.engine = RegexEngine()  # Create new engine
        self.ast = other.ast
        self.pattern_string = other.pattern_string

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.engine = RegexEngine()  # Create new engine
        self.ast = other.ast^
        self.pattern_string = other.pattern_string^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using NFA execution."""
        return self.engine.match_first(self.ast, text, start)

    fn match_all(self, text: String) raises -> List[Match]:
        """Find all matches using NFA execution."""
        var result = self.engine.match_all(
            self.pattern_string, text, return_matches=True
        )
        return result[2]  # Return the matches list


struct HybridMatcher(Copyable, Movable, RegexMatcher):
    """Intelligent matcher that routes to optimal engine based on pattern complexity.
    """

    var dfa_matcher: Optional[DFAMatcher]
    var nfa_matcher: NFAMatcher
    var complexity: PatternComplexity
    var pattern_string: String

    fn __init__(out self, pattern: String) raises:
        """Initialize hybrid matcher by analyzing pattern and creating appropriate engines.

        Args:
            pattern: Regex pattern string to compile
        """
        self.pattern_string = pattern
        var ast = parse(pattern)

        # Analyze pattern complexity
        var analyzer = PatternAnalyzer()
        self.complexity = analyzer.classify(ast)

        # Always create NFA matcher as fallback
        self.nfa_matcher = NFAMatcher(ast, pattern)

        # Create DFA matcher if pattern is simple enough
        if self.complexity.value == PatternComplexity.SIMPLE:
            try:
                self.dfa_matcher = DFAMatcher(ast, pattern)
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
        self.pattern_string = other.pattern_string

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.dfa_matcher = other.dfa_matcher^
        self.nfa_matcher = other.nfa_matcher^
        self.complexity = other.complexity
        self.pattern_string = other.pattern_string^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match using optimal engine."""
        if (
            self.dfa_matcher
            and self.complexity.value == PatternComplexity.SIMPLE
        ):
            # Use high-performance DFA for simple patterns
            return self.dfa_matcher.value().match_first(text, start)
        else:
            # Fall back to NFA for complex patterns
            return self.nfa_matcher.match_first(text, start)

    fn match_all(self, text: String) raises -> List[Match]:
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
            String indicating which engine is active ("DFA", "NFA", or "Hybrid")
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
            PatternComplexity classification
        """
        return self.complexity


struct CompiledRegex(Copyable, Movable):
    """High-level compiled regex object with caching and optimization."""

    var matcher: HybridMatcher
    var pattern: String
    var compiled_at: Int  # Timestamp for cache management

    fn __init__(out self, pattern: String) raises:
        """Compile a regex pattern with automatic optimization.

        Args:
            pattern: Regex pattern string
        """
        self.pattern = pattern
        self.matcher = HybridMatcher(pattern)
        # TODO: Add actual timestamp when time module is available
        self.compiled_at = 0

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.matcher = other.matcher
        self.pattern = other.pattern
        self.compiled_at = other.compiled_at

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.matcher = other.matcher^
        self.pattern = other.pattern^
        self.compiled_at = other.compiled_at

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find first match in text.

        Args:
            text: Input text to search
            start: Starting position (default 0)

        Returns:
            Optional Match if found
        """
        return self.matcher.match_first(text, start)

    fn match_all(self, text: String) raises -> List[Match]:
        """Find all matches in text.

        Args:
            text: Input text to search

        Returns:
            List of all matches found
        """
        return self.matcher.match_all(text)

    fn test(self, text: String) -> Bool:
        """Test if pattern matches anywhere in text.

        Args:
            text: Input text to test

        Returns:
            True if pattern matches, False otherwise
        """
        var result = self.match_first(text)
        return result.__bool__()

    fn get_stats(self) -> String:
        """Get performance statistics and engine information.

        Returns:
            String with debugging information
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


# Global pattern cache for improved performance
# TODO: Implement LRU cache when Dict supports it properly
var __pattern_cache = List[CompiledRegex]()
var __cache_patterns = List[String]()


fn compile_regex(pattern: String) raises -> CompiledRegex:
    """Compile a regex pattern with caching for repeated use.

    Args:
        pattern: Regex pattern string

    Returns:
        Compiled regex object ready for matching
    """
    # Simple linear search in cache (TODO: use proper hash map)
    for i in range(len(__cache_patterns)):
        if __cache_patterns[i] == pattern:
            return __pattern_cache[i]

    # Not in cache, compile new regex
    var compiled = CompiledRegex(pattern)

    # Add to cache (TODO: implement LRU eviction)
    if len(__cache_patterns) < 100:  # Simple cache size limit
        __cache_patterns.append(pattern)
        __pattern_cache.append(compiled)

    return compiled


fn clear_regex_cache():
    """Clear the compiled regex cache."""
    __cache_patterns.clear()
    __pattern_cache.clear()


# High-level convenience functions that match Python's re module interface
fn search(pattern: String, text: String) raises -> Optional[Match]:
    """Search for pattern in text (equivalent to re.search in Python).

    Args:
        pattern: Regex pattern string
        text: Text to search in

    Returns:
        Optional Match if found
    """
    var compiled = compile_regex(pattern)
    return compiled.match_first(text)


fn findall(pattern: String, text: String) raises -> List[Match]:
    """Find all matches of pattern in text (equivalent to re.findall in Python).

    Args:
        pattern: Regex pattern string
        text: Text to search in

    Returns:
        List of all matches found
    """
    var compiled = compile_regex(pattern)
    return compiled.match_all(text)


fn match_first(pattern: String, text: String) raises -> Optional[Match]:
    """Match pattern at beginning of text (equivalent to re.match in Python).

    Args:
        pattern: Regex pattern string
        text: Text to match against

    Returns:
        Optional Match if pattern matches at start of text
    """
    var compiled = compile_regex(pattern)
    var result = compiled.match_first(text, 0)

    # Python's re.match only succeeds if match starts at position 0
    if result and result.value().start_idx == 0:
        return result
    else:
        return None
