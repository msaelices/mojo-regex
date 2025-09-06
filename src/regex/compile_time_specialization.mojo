"""
Compile-time pattern specialization for literal regex patterns.

This module implements compile-time generation of specialized matcher functions
for literal patterns, providing significant performance improvements over the
general-purpose regex engine for common literal matching scenarios.
"""

from builtin._location import __call_location
from memory import UnsafePointer
from regex.aliases import EMPTY_SLICE
from regex.ast import ASTNode, ELEMENT, RE, GROUP
from regex.matching import Match


# ===-----------------------------------------------------------------------===#
# Compile-Time Pattern Analysis
# ===-----------------------------------------------------------------------===#


@always_inline
fn _is_literal_only_pattern[pattern: StaticString]() -> Bool:
    """Check if a pattern is literal-only at compile time.

    Parameters:
        pattern: The regex pattern to analyze.

    Returns:
        True if the pattern contains only literal characters.
    """
    # Simple compile-time analysis - check for regex metacharacters
    var has_metachar = False

    @parameter
    for i in range(len(pattern)):
        var c = pattern[i]
        if (
            c == "*"
            or c == "+"
            or c == "?"
            or c == "."
            or c == "|"
            or c == "("
            or c == ")"
            or c == "["
            or c == "]"
            or c == "{"
            or c == "}"
            or c == "^"
            or c == "$"
            or c == "\\"
        ):
            has_metachar = True
            break

    return not has_metachar


@always_inline
fn _get_pattern_length[pattern: StaticString]() -> Int:
    """Get the length of a compile-time pattern.

    Parameters:
        pattern: The pattern to measure.

    Returns:
        The length of the pattern.
    """
    return len(pattern)


# ===-----------------------------------------------------------------------===#
# Specialized Literal Matchers
# ===-----------------------------------------------------------------------===#


@always_inline
fn _match_literal_exact[
    pattern: StaticString
](text: String, start: Int = 0) -> Optional[Match]:
    """Specialized exact literal matcher generated at compile time.

    This function is optimized for exact literal matching and bypasses
    the general regex engine entirely.

    Parameters:
        pattern: The literal pattern to match (known at compile time).

    Args:
        text: Text to search in.
        start: Starting position.

    Returns:
        Optional Match if found, None otherwise.
    """
    var pattern_len = len(pattern)
    var text_len = len(text)

    # Bounds check
    if start < 0 or start + pattern_len > text_len:
        return None

    # Fast character-by-character comparison
    @parameter
    for i in range(len(pattern)):
        if text[start + i] != pattern[i]:
            return None

    return Match(0, start, start + pattern_len, text)


@always_inline
fn _match_literal_first[
    pattern: StaticString
](text: String, start: Int = 0) -> Optional[Match]:
    """Specialized literal matcher that finds first occurrence.

    Uses optimized string search for better performance.

    Parameters:
        pattern: The literal pattern to match.

    Args:
        text: Text to search in.
        start: Starting position.

    Returns:
        Optional Match if found, None otherwise.
    """
    var pos = text.find(pattern, start)
    if pos != -1:
        var pattern_len = len(pattern)
        return Match(0, pos, pos + pattern_len, text)
    return None


@always_inline
fn _match_literal_all[pattern: StaticString](text: String) -> List[Match]:
    """Specialized literal matcher that finds all occurrences.

    Parameters:
        pattern: The literal pattern to match.

    Args:
        text: Text to search in.

    Returns:
        List of all matches found.
    """
    var matches = List[Match]()
    var pattern_len = len(pattern)
    var pos = 0

    while True:
        var found_pos = text.find(pattern, pos)
        if found_pos == -1:
            break

        matches.append(Match(0, found_pos, found_pos + pattern_len, text))
        pos = (
            found_pos + pattern_len
        )  # Move past this match to avoid overlapping

    return matches


# ===-----------------------------------------------------------------------===#
# Compile-Time Matcher Generation
# ===-----------------------------------------------------------------------===#


struct CompileTimeMatcher(ImplicitlyCopyable, Movable):
    """Matcher that uses compile-time specialization for literal patterns."""

    var pattern: String
    """The original pattern string."""

    fn __init__(out self, pattern: String):
        """Initialize with a pattern."""
        self.pattern = pattern

    fn match_first(self, text: String, start: Int = 0) -> Optional[Match]:
        """Match first occurrence using compile-time specialization."""
        # This would ideally be replaced with compile-time pattern analysis
        # For now, fall back to runtime detection
        if self._is_literal_pattern():
            return self._match_literal_runtime(text, start)
        else:
            # Fall back to general engine
            return None

    fn match_all(self, text: String) -> List[Match]:
        """Match all occurrences using compile-time specialization."""
        if self._is_literal_pattern():
            return self._match_all_literal_runtime(text)
        else:
            return List[Match]()

    fn _is_literal_pattern(self) -> Bool:
        """Runtime check if pattern is literal-only."""
        var pattern = self.pattern
        for i in range(len(pattern)):
            var c = pattern[i]
            if (
                c == "*"
                or c == "+"
                or c == "?"
                or c == "."
                or c == "|"
                or c == "("
                or c == ")"
                or c == "["
                or c == "]"
                or c == "{"
                or c == "}"
                or c == "^"
                or c == "$"
                or c == "\\"
            ):
                return False
        return True

    fn _match_literal_runtime(
        self, text: String, start: Int
    ) -> Optional[Match]:
        """Runtime literal matching fallback."""
        var pos = text.find(self.pattern, start)
        if pos != -1 and pos == start:
            return Match(0, pos, pos + len(self.pattern), text)
        return None

    fn _match_all_literal_runtime(self, text: String) -> List[Match]:
        """Runtime literal matching for all occurrences."""
        var matches = List[Match]()
        var pattern_len = len(self.pattern)
        var pos = 0

        while True:
            var found_pos = text.find(self.pattern, pos)
            if found_pos == -1:
                break

            matches.append(Match(0, found_pos, found_pos + pattern_len, text))
            pos = found_pos + pattern_len

        return matches


# ===-----------------------------------------------------------------------===#
# Integration with Existing Matcher
# ===-----------------------------------------------------------------------===#


fn create_specialized_matcher(pattern: String) -> Optional[CompileTimeMatcher]:
    """Create a specialized matcher if the pattern qualifies.

    Args:
        pattern: The regex pattern.

    Returns:
        Optional specialized matcher, or None if pattern doesn't qualify.
    """
    var matcher = CompileTimeMatcher(pattern)
    if matcher._is_literal_pattern():
        return matcher
    return None


# ===-----------------------------------------------------------------------===#
# Example Usage (Compile-Time)
# ===-----------------------------------------------------------------------===#

# These would be the ideal compile-time usage patterns:
# fn match_hello(text: String) -> Optional[Match]:
#     return _match_literal_exact["hello"](text)
#
# fn match_world(text: String) -> Optional[Match]:
#     return _match_literal_first["world"](text)
#
# fn find_all_test(text: String) -> List[Match]:
#     return _match_literal_all["test"](text)
