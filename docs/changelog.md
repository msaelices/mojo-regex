# Changelog

All notable changes to `mojo-regex` are documented in this file.

## [0.7.0] - 2026-03-23

### Performance
- Pre-allocate String capacity in range expansion loops (#61)
- Fix SIMD character class matcher silently disabled by Mojo 0.26.2 Optional bug (#62)
- Route grouped literal alternations to DFA engine instead of NFA (#64)
- Use SIMD matcher to skip non-matching positions in match_all (#65)
- Optimize negated character class transition building (#66)
- Add zero-allocation `is_match_char` for NFA character matching (#63)

### Changed
- Replace all `fn` declarations with `def` (#60)
- Fix all compiler warnings: `alias` -> `comptime`, `@parameter` -> `comptime`,
  `Stringable` -> `Writable`, implicit stdlib imports, deprecated conversions (#67)
- Fix CI: avoid StringSlice mutability issue and SIMD bool construction (#66)

### Benchmark highlights (vs 0.6.0)
- `large_8_alternations`: 80x faster (DFA routing fix)
- `match_all_digits`: 16x faster (SIMD skip in match_all)
- `literal_prefix_long`: 14.5x faster (zero-allocation is_match_char)
- `range_digits`: 2.6x faster (SIMD matcher Optional bug fix)
- `predefined_digits`: 3.9x faster (SIMD matcher Optional bug fix)

## [0.6.0] - 2026-03-22

### Changed
- Upgrade from Mojo nightly 0.25.7 to stable 0.26.2 (#59)
- Migrate all source, test, and benchmark files to Mojo 0.26.2 API
- Origin type renames (ImmutableOrigin -> ImmutOrigin, etc.)
- `@register_passable("trivial")` -> `TrivialRegisterPassable` trait
- `UnsafePointer` API changes (explicit origin params, `alloc()` free function)
- `__copyinit__`/`__moveinit__` parameter naming (`copy`/`take`/`deinit`)
- String/StringSlice subscripting now requires `byte=` keyword
- `mojo test` removed, migrated to `TestSuite.discover_tests` pattern
- `vectorize` closures updated to `unified` convention with explicit captures
- Switch pixi channel from nightly to stable

### Performance
- Optimize hot paths to use `Int(text.unsafe_ptr()[pos])` instead of
  `ord(text[byte=pos])` for ~7x per-byte-access improvement

## [0.5.0] - 2025-09-20

### Changed
- Upgrade to Mojo 0.25.7.0.dev2025092005 (#56)
- Update to Mojo 0.25.6.0.dev2025090805 (#55)
- Update to Mojo 0.25.6.0.dev2025090605 (#53)
- Upgrade Mojo to 0.26.0.dev2025090505 (#51)

### Performance
- Optimize LiteralInfo struct to be register passable (#52)
- Optimize predefined character classes and SIMD performance (#48)
- Optimize check_for_quantifiers to eliminate string allocations (#44)

### Added
- Implement `\d` and `\w` predefined character classes (#47)

### Fixed
- Fix build issues by refactoring to standalone SIMD functions (#45)

## [0.4.0] - 2025-08-31

### Performance
- Extend DFA pattern coverage with selective optimizer improvements (#35)
- Optimize findall performance by preallocating estimated matches (#36)
- Optimize MatchList with lazy allocation and UnsafePointer internals (#37, #38)
- Implement Rust-inspired prefilter system for regex optimization (#28)
- Enhance DFA engine with advanced pattern support (common prefix alternation,
  quantified alternation groups) (#24)
- Optimize var->ref conversions across core modules (#25)
- Optimize .* wildcard pattern by bypassing regex compilation

### Added
- Literal extraction and prefiltering for faster pattern matching (#18)
- SIMD byte lookup for character class matching (#19)
- US phone number parsing benchmarks (#32)
- Rust regex benchmark comparison infrastructure (#23)

### Fixed
- Fix critical regex engine state corruption bug (#40)
- Fix critical dangling pointer vulnerability in SIMDStringSearch (#43, #22)

### Changed
- Upgrade to Mojo 25.6.0.dev2025082505 (#41)
- Refactor SIMD operations to use Span[Byte] instead of pointer+length (#46)
- Replace benchmark module with manual timing for fair Python comparison (#30)

## [0.3.0] - 2025-07-31

### Performance
- Optimize ASTNode: eliminate copying in backtracking (#10, #12)
- Prevent String allocations in hot paths (#13)
- Small optimizations - part 4 (#14)

### Added
- Add comprehensive docstrings (#16)
- Add benchmarking framework for performance analysis (#17)

### Fixed
- Fix memory corruptions in ASTNode rebind

## [0.2.0] - 2025-07-04

### Performance
- Hybrid DFA/NFA Engine Architecture (#3, #4, #5)
- Optimize NFA match_first for better performance and Python re.match()
  compatibility (#6)
- Make Match struct trivial and avoid string copies (#9)

### Added
- Phone number pattern matching support (#7)
- GH Actions CI pipeline (#1)
- Improved benchmarks (#2)

## [0.1.0] - 2025-06-27

### Added
- Initial release
- Regex lexer, parser, and AST
- NFA-based regex matching engine
- Support for basic patterns: literals, wildcards (`.`), quantifiers (`*`, `+`, `?`),
  character ranges (`[a-z]`), alternation (`a|b`), groups (`(abc)`),
  anchors (`^`, `$`), and escape sequences (`\d`, `\w`, `\s`)
- `match_first`, `findall`, and `search` public API
- Pixi-based build and test infrastructure
