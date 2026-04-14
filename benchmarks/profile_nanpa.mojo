"""Profile the NANPA pattern to understand where time is spent in the lazy DFA.

Instruments match_first, match_next, and findall on the full US NANPA area
code pattern to identify the bottleneck.
"""

from std.time import perf_counter_ns

from regex.matcher import compile_regex, search, findall, match_first
from regex.aliases import ImmSlice


comptime NANPA = "(?:2(?:0[1-35-9]|1[02-9]|2[03-57-9]|3[1459]|4[08]|5[1-46]|6[0279]|7[0269]|8[13])|3(?:0[1-47-9]|1[02-9]|2[0135-79]|3[0-24679]|4[167]|5[0-2]|6[01349]|8[056])|4(?:0[124-9]|1[02-579]|2[3-5]|3[0245]|4[023578]|58|6[349]|7[0589]|8[04])|5(?:0[1-47-9]|1[0235-8]|20|3[0149]|4[01]|5[179]|6[1-47]|7[0-5]|8[0256])|6(?:0[1-35-9]|1[024-9]|2[03689]|3[016]|4[0156]|5[01679]|6[0-279]|78|8[0-29])|7(?:0[1-46-8]|1[2-9]|2[04-8]|3[0-247]|4[037]|5[47]|6[02359]|7[0-59]|8[156])|8(?:0[1-68]|1[02-8]|2[0168]|3[0-2589]|4[03578]|5[046-9]|6[02-5]|7[028])|9(?:0[1346-9]|1[02-9]|2[0589]|3[0146-8]|4[01357-9]|5[12469]|7[0-389]|8[04-69]))[2-9]\\d{6}"


def time_ns(start: UInt) -> Float64:
    return Float64(perf_counter_ns() - start) / 1000.0  # microseconds


def main() raises:
    print("=== NANPA Pattern Profiling ===")
    print()

    # --- 1. Compilation profiling ---
    var t0 = perf_counter_ns()
    var compiled = compile_regex(NANPA)
    var compile_us = time_ns(t0)
    print("1. Compile time:", compile_us, "us")
    print("   Engine:", compiled.get_stats())
    print()

    # --- 2. match_first on a single 10-digit number ---
    var number = "6502530000"
    # Warmup
    for _ in range(100):
        _ = compiled.match_first(number)

    var iters = 10000
    t0 = perf_counter_ns()
    for _ in range(iters):
        var m = compiled.match_first(number)
        if not m:
            print("ERROR: no match")
            return
    var match_first_us = time_ns(t0) / Float64(iters)
    print("2. match_first per call:", match_first_us, "us")
    print()

    # --- 3. match_next (search) on text with multiple numbers ---
    var text = "Call 6502530000 or 2125551234 or 9175559876 today."
    # Warmup
    for _ in range(100):
        _ = compiled.match_next(text)

    iters = 5000
    t0 = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.match_next(text)
    var match_next_us = time_ns(t0) / Float64(iters)
    print("3. match_next (search) per call:", match_next_us, "us")
    print()

    # --- 4. Breakdown: NFA engine vs lazy DFA ---
    # NFA engine match_first
    iters = 10000
    t0 = perf_counter_ns()
    for _ in range(iters):
        _ = compiled.matcher.nfa_matcher.engine.match_first(number)
    var nfa_us = time_ns(t0) / Float64(iters)
    print("4a. NFA engine match_first per call:", nfa_us, "us")

    # Lazy DFA match_first (if available)
    if compiled.matcher.nfa_matcher._lazy_dfa_ptr:
        t0 = perf_counter_ns()
        for _ in range(iters):
            _ = compiled.matcher.nfa_matcher._lazy_dfa_ptr[].match_first(number)
        var lazy_us = time_ns(t0) / Float64(iters)
        print("4b. Lazy DFA match_first per call:", lazy_us, "us")
        print(
            "    Cached states:",
            len(compiled.matcher.nfa_matcher._lazy_dfa_ptr[].states),
        )
    else:
        print("4b. Lazy DFA: NOT AVAILABLE")
    print()

    # --- 5. Use lazy DFA for search check ---
    print(
        "5. Uses lazy DFA for search:",
        compiled.matcher.nfa_matcher._use_lazy_dfa_for_search(),
    )
    print(
        "   NFA has_literal_optimization:",
        compiled.matcher.nfa_matcher.engine.has_literal_optimization,
    )
    print(
        "   NFA literal_prefix:",
        repr(compiled.matcher.nfa_matcher.engine.literal_prefix),
    )
    print()

    # --- 6. findall on repeated text ---
    var big_text = String()
    for _ in range(20):
        big_text += "Call 6502530000 or 2125551234 or 9175559876. "

    iters = 100
    t0 = perf_counter_ns()
    for _ in range(iters):
        var matches = compiled.match_all(big_text)
        if len(matches) == 0:
            print("ERROR: no findall matches")
            return
    var findall_us = time_ns(t0) / Float64(iters)
    print("6. findall (20 repeats, ~60 matches) per call:", findall_us, "us")
    var matches = compiled.match_all(big_text)
    print("   Found", len(matches), "matches")
    print()

    # --- 7. Compare: simple phone pattern vs NANPA ---
    var simple = compile_regex("\\d{10}")
    iters = 10000
    t0 = perf_counter_ns()
    for _ in range(iters):
        _ = simple.match_first(number)
    var simple_us = time_ns(t0) / Float64(iters)
    print("7. Simple \\d{10} match_first:", simple_us, "us")
    print("   NANPA / simple ratio:", match_first_us / simple_us, "x")
    print()

    # --- 8. Python comparison reference ---
    print("=== Reference: Python re module times (from benchmark) ===")
    print("   nanpa_match_first: ~0.198 us (Python)")
    print("   nanpa_search:      ~0.288 us (Python)")
    print("   nanpa_findall:     ~34.7 us  (Python, 50 repeats)")
    print()
    print("   Mojo nanpa_match_first:", match_first_us, "us")
    print("   Mojo / Python ratio:", match_first_us / 0.198, "x slower")
