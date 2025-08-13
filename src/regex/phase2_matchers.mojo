"""
Phase 2 matcher wrappers for integration with the HybridMatcher system.

This module provides wrapper classes that integrate the One-Pass DFA and Lazy DFA
engines into the existing RegexMatcher trait system.
"""

from regex.ast import ASTNode
from regex.matching import Match
from regex.onepass_dfa import (
    OnePassDFA,
    compile_one_pass_dfa,
    can_build_one_pass_dfa,
)
from regex.lazy_dfa import LazyDFA, create_lazy_dfa_for_alternation


trait RegexMatcher:
    """Base trait for regex matcher implementations."""

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match in the text."""
        ...

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the next match after start position."""
        ...

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all matches in the text."""
        ...


struct OnePassMatcher(Copyable, Movable, RegexMatcher):
    """Wrapper for One-Pass DFA engine that conforms to RegexMatcher trait."""

    var engine: OnePassDFA
    """The underlying One-Pass DFA engine."""
    var pattern: String
    """Original pattern string for debugging."""

    fn __init__(
        out self, ast: ASTNode[MutableAnyOrigin], pattern: String
    ) raises:
        """Initialize One-Pass matcher from AST.

        Args:
            ast: Parsed AST of the regex pattern.
            pattern: Original pattern string.

        Raises:
            Error if pattern cannot be compiled to One-Pass DFA.
        """
        self.pattern = pattern
        self.engine = compile_one_pass_dfa(ast)

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.engine = other.engine
        self.pattern = other.pattern

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.engine = other.engine^
        self.pattern = other.pattern^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match using One-Pass DFA."""
        return self.engine.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the next match using One-Pass DFA."""
        return self.engine.match_next(text, start)

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all matches using One-Pass DFA."""
        return self.engine.match_all(text)


struct LazyDFAMatcher(Copyable, Movable, RegexMatcher):
    """Wrapper for Lazy DFA engine that conforms to RegexMatcher trait."""

    var engine: LazyDFA
    """The underlying Lazy DFA engine."""
    var pattern: String
    """Original pattern string for debugging."""

    fn __init__(
        out self, ast: ASTNode[MutableAnyOrigin], pattern: String
    ) raises:
        """Initialize Lazy DFA matcher from AST.

        Args:
            ast: Parsed AST of the regex pattern.
            pattern: Original pattern string.
        """
        self.pattern = pattern
        self.engine = create_lazy_dfa_for_alternation(ast)

    fn __copyinit__(out self, other: Self):
        """Copy constructor."""
        self.engine = other.engine
        self.pattern = other.pattern

    fn __moveinit__(out self, owned other: Self):
        """Move constructor."""
        self.engine = other.engine^
        self.pattern = other.pattern^

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the first match using Lazy DFA."""
        return self.engine.match_first(text, start)

    fn match_next(self, text: String, start: Int = 0) -> Optional[Match]:
        """Find the next match using Lazy DFA."""
        return self.engine.match_next(text, start)

    fn match_all(self, text: String) -> List[Match, hint_trivial_type=True]:
        """Find all matches using Lazy DFA."""
        return self.engine.match_all(text)

    fn get_cache_stats(self) -> String:
        """Get cache performance statistics."""
        return self.engine.get_cache_stats()


fn can_use_one_pass_matcher(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern can use One-Pass DFA matcher.

    Args:
        ast: Parsed AST to check.

    Returns:
        True if One-Pass DFA is suitable.
    """
    return can_build_one_pass_dfa(ast)


fn should_use_lazy_dfa_matcher(ast: ASTNode[MutableAnyOrigin]) -> Bool:
    """Check if pattern should use Lazy DFA matcher.

    Args:
        ast: Parsed AST to check.

    Returns:
        True if Lazy DFA is beneficial.
    """
    from regex.lazy_dfa import should_use_lazy_dfa

    return should_use_lazy_dfa(ast)
