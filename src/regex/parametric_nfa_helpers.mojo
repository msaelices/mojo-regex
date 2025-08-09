"""Parametric helper functions for NFA engine to work with any SIMDMatcher type."""

from regex.simd_matchers import SIMDMatcher


fn apply_quantifier_simd_generic[
    T: SIMDMatcher
](
    matcher: T,
    text: String,
    start_pos: Int,
    min_matches: Int,
    max_matches: Int,
) -> Tuple[Bool, Int]:
    """Apply quantifier using SIMD for faster bulk matching.

    This is a generic version that works with any SIMDMatcher implementation.

    Parameters:
        T: The concrete type implementing SIMDMatcher.

    Args:
        matcher: The SIMD matcher instance.
        text: Input string.
        start_pos: Current position.
        min_matches: Minimum required matches.
        max_matches: Maximum allowed matches (-1 for unlimited).

    Returns:
        Tuple of (success, final_position).
    """
    var pos = start_pos
    var match_count = 0
    var actual_max = max_matches
    if actual_max == -1:
        actual_max = len(text) - start_pos

    # Count consecutive matching characters
    while pos < len(text) and match_count < actual_max:
        if matcher.contains(ord(text[pos])):
            match_count += 1
            pos += 1
        else:
            break

    # Check if we satisfied the quantifier
    if match_count >= min_matches:
        return (True, pos)
    else:
        return (False, start_pos)


fn find_in_text_simd[
    T: SIMDMatcher
](matcher: T, text: String, start: Int = 0, end: Int = -1,) -> Int:
    """Find first occurrence of a character matching the given matcher.

    Parameters:
        T: The concrete type implementing SIMDMatcher.

    Args:
        matcher: The SIMD matcher instance.
        text: Text to search.
        start: Starting position.
        end: Ending position (-1 for end of string).

    Returns:
        Position of first match, or -1 if not found.
    """
    var actual_end = end if end != -1 else len(text)
    var pos = start

    # Process in SIMD chunks for speed
    while pos + 16 <= actual_end:
        var chunk = text.unsafe_ptr().load[width=16](pos)
        var matches = matcher.match_chunk(chunk)

        # Check if any match in chunk
        if matches.reduce_or():
            # Find first match position
            for i in range(16):
                if matches[i]:
                    return pos + i

        pos += 16

    # Handle remaining characters
    while pos < actual_end:
        if matcher.contains(ord(text[pos])):
            return pos
        pos += 1

    return -1
