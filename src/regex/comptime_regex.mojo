"""Compile-time pattern specialization (comptime regex).

Implements step 1 of `proposals/comptime-regex.md`: the pattern is a
comptime parameter, so the parser and the DFA compiler run inside the
comptime interpreter and the resulting automaton is embedded in the
binary. Matching then needs no runtime compilation, no pattern hash
and no cache probe.

    from regex.comptime_regex import search

    var m = search["hello"](text)

Dispatch happens at compile time:

- Invalid patterns (parse errors) fail the build via `comptime assert`.
- Patterns the DFA compiler supports (literals, anchors, quantifiers,
  alternations, character classes, `\\d`/`\\w` shorthands, wildcards,
  bounded quantifiers, multi-class sequences) use the comptime-built
  engine.
- Everything else falls back to the runtime engine (`regex.matcher`),
  keeping full feature parity.

Materialization strategy: `materialize[...]()` copies per call, so the
comptime-built `DFAEngine` is materialized exactly once per pattern per
process into a `_Global` slot (named `__ctregex__:<pattern>`), and every
call goes through the returned pointer. See the proposal's
"Materialization strategy" section for the static-data alternative.
"""

from std.ffi import _Global
from std.os import abort

from regex.aliases import ImmSlice, imm_slice_from_ptr
from regex.dfa import DFAEngine, compile_dfa_pattern
from regex.matching import Match, MatchList
from regex.matcher import (
    search as _runtime_search,
    match_first as _runtime_match_first,
    findall as _runtime_findall,
)
from regex.parser import parse


# ===----------------------------------------------------------------=== #
# Comptime probe
# ===----------------------------------------------------------------=== #


@fieldwise_init
struct _CtProbe(Copyable, Movable):
    """Result of the comptime pattern classification."""

    var parse_ok: Bool
    """False when the pattern does not parse at all (build error)."""
    var dfa_ok: Bool
    """True when the full comptime DFA pipeline is available."""


def _probe(pattern: StaticString) -> _CtProbe:
    """Classify a pattern at comptime.

    Runs the real parser and the real DFA compiler inside the comptime
    interpreter. The DFA build uses `use_matcher_cache=False` so SIMD
    char-class matchers are constructed directly: the `_Global` cache's
    external FFI call is a hard comptime-interpreter error, while every
    remaining failure mode ("pattern too complex") is a regular
    catchable exception. The functions are `raises`, and raising
    functions cannot initialize a `comptime` value, so failures are
    folded into flags.

    Args:
        pattern: The regex pattern (comptime value).

    Returns:
        The probe flags driving `comptime assert` / `comptime if`.
    """
    try:
        var ast = parse(String(pattern))
        try:
            _ = compile_dfa_pattern[use_matcher_cache=False](ast)
            return _CtProbe(parse_ok=True, dfa_ok=True)
        except:
            # Valid regex, but rejected by the DFA compiler; falls back
            # to the runtime engine.
            return _CtProbe(parse_ok=True, dfa_ok=False)
    except:
        return _CtProbe(parse_ok=False, dfa_ok=False)


def _build_engine(pattern: StaticString) -> DFAEngine:
    """Build the DFA engine at comptime.

    Only reachable when `_probe(pattern).dfa_ok` held, so the raising
    paths are dead; they are mapped to `abort` to keep this callable
    from a `comptime` initializer.

    Args:
        pattern: The regex pattern (comptime value).

    Returns:
        The compiled engine, as a plain comptime value.
    """
    try:
        var ast = parse(String(pattern))
        return compile_dfa_pattern[use_matcher_cache=False](ast)
    except e:
        abort(String(e))


# ===----------------------------------------------------------------=== #
# Per-pattern process-global engine
# ===----------------------------------------------------------------=== #


def _init_ct_engine[pattern: StaticString]() -> DFAEngine:
    """Materialize the comptime-built engine (runs once per process)."""
    comptime ENGINE = _build_engine(pattern)
    return materialize[ENGINE]()


def _get_ct_engine[
    pattern: StaticString
]() -> Pointer[DFAEngine, MutUntrackedOrigin]:
    """Return the process-global engine for `pattern`.

    The `_Global` slot is keyed by the pattern itself under the
    `__ctregex__:` namespace so it cannot collide with the runtime
    cache globals ("RegexCache", "LastSubCache", "SIMDMatchers").
    """
    # Build the per-pattern slot name as a comptime `StaticString`.
    # (`get_static_string` was removed from the public stdlib API in
    # 1.0.0; a type-annotated comptime concatenation interns the same
    # static string.)
    comptime slot_name: StaticString = "__ctregex__:" + pattern
    comptime ENGINE_GLOBAL = _Global[
        slot_name,
        _init_ct_engine[pattern],
    ]
    try:
        return ENGINE_GLOBAL.get_or_create_ptr()
    except e:
        abort(String(e))


def _pattern_slice[pattern: StaticString]() -> ImmSlice:
    """View the comptime pattern as an `ImmSlice` for the runtime API,
    without allocating a `String` per call."""
    return imm_slice_from_ptr(
        pattern.unsafe_ptr().as_unsafe_any_origin(), pattern.byte_length()
    )


# ===----------------------------------------------------------------=== #
# Public API
# ===----------------------------------------------------------------=== #


def search[
    O: ImmOrigin, //, pattern: StaticString
](text: StringSlice[O]) raises -> Optional[Match[O]]:
    """Search for `pattern` in `text` (equivalent to `re.search`).

    Same semantics as `regex.search(pattern, text)`, with the pattern
    lifted to a comptime parameter. Invalid patterns fail the build.

    Parameters:
        O: Origin of the text.
        pattern: Regex pattern (comptime).

    Args:
        text: Text to search in.

    Returns:
        Optional Match if found.
    """
    comptime probe = _probe(pattern)
    comptime assert probe.parse_ok, "invalid regex pattern (parse error)"
    comptime if probe.dfa_ok:
        return _get_ct_engine[pattern]()[].match_next(text)
    else:
        return _runtime_search(_pattern_slice[pattern](), text)


def match_first[
    O: ImmOrigin, //, pattern: StaticString
](text: StringSlice[O]) raises -> Optional[Match[O]]:
    """Match `pattern` at the beginning of `text` (like `re.match`).

    Parameters:
        O: Origin of the text.
        pattern: Regex pattern (comptime).

    Args:
        text: Text to match against.

    Returns:
        Optional Match if the pattern matches at position 0.
    """
    comptime probe = _probe(pattern)
    comptime assert probe.parse_ok, "invalid regex pattern (parse error)"
    comptime if probe.dfa_ok:
        var result = _get_ct_engine[pattern]()[].match_first(text, 0)
        # Mirror `regex.matcher.match_first`: Python's re.match only
        # succeeds when the match starts at position 0.
        if result and result.value().start_idx == 0:
            return result
        else:
            return None
    else:
        return _runtime_match_first(_pattern_slice[pattern](), text)


def findall[
    O: ImmOrigin, //, pattern: StaticString
](text: StringSlice[O]) raises -> MatchList[O]:
    """Find all matches of `pattern` in `text` (like `re.findall`).

    Parameters:
        O: Origin of the text.
        pattern: Regex pattern (comptime).

    Args:
        text: Text to search in.

    Returns:
        MatchList with all non-overlapping matches.
    """
    comptime probe = _probe(pattern)
    comptime assert probe.parse_ok, "invalid regex pattern (parse error)"
    comptime if probe.dfa_ok:
        return _get_ct_engine[pattern]()[].match_all(text)
    else:
        return _runtime_findall(_pattern_slice[pattern](), text)
