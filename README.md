# Mojo Regex
Mojo Regular Expressions Library

`mojo-regex` is a lightweight library for handling regular expressions in Mojo.

It aims to provide a similar interface as the [re](https://docs.python.org/3/library/re.html) stdlib package.

## Disclaimer ⚠️

This software is in an early stage of development. Please DO NOT use yet for production ready services.

## Architecture

The library follows a traditional regex engine architecture:

- **Lexer** (`lexer.mojo`): Tokenizes regex strings into a stream of tokens
- **Parser** (`parser.mojo`): Builds an Abstract Syntax Tree (AST) from tokens
- **AST** (`ast.mojo`): Represents regex patterns as tree structures
- **Engine** (`engine.mojo`): Executes pattern matching with backtracking
- **Tokens** (`tokens.mojo`): Defines all regex token types

## Implemented Features

### Basic Elements
- ✅ Literal characters (`a`, `hello`)
- ✅ Wildcard (`.`) - matches any character except newline
- ✅ Whitespace (`\s`) - matches space, tab, newline, carriage return, form feed
- ✅ Escape sequences (`\t` for tab, `\\` for literal backslash)

### Character Classes
- ✅ Character ranges (`[a-z]`, `[0-9]`, `[A-Za-z0-9]`)
- ✅ Negated ranges (`[^a-z]`, `[^0-9]`)
- ✅ Mixed character sets (`[abc123]`)
- ✅ Character ranges within groups (`(b|[c-n])`)

### Quantifiers
- ✅ Zero or more (`*`)
- ✅ One or more (`+`)
- ✅ Zero or one (`?`)
- ✅ Exact count (`{3}`)
- ✅ Range count (`{2,4}`)
- ✅ Minimum count (`{2,}`)
- ✅ Quantifiers on all elements (characters, wildcards, ranges, groups)

### Anchors
- ✅ Start of string (`^`)
- ✅ End of string (`$`)
- ✅ Anchors in OR expressions (`^na|nb$`)

### Groups and Alternation
- ✅ Capturing groups (`(abc)`)
- ✅ Alternation/OR (`a|b`)
- ✅ Complex OR patterns (`(a|b)`, `na|nb`)
- ✅ Nested alternations (`(b|[c-n])`)
- ✅ Group quantifiers (`(a)*`, `(abc)+`)

### Engine Features
- ✅ Greedy matching with backtracking
- ✅ Pattern compilation caching
- ✅ Match position tracking (start_idx, end_idx)
- ✅ Simple API: `match_first(pattern, text) -> Optional[Match]`

## Installation

1. **Install [pixi](https://pixi.sh/latest/)**

2. **Add the Package** (at the top level of your project):

    ```bash
    pixi add regex
    ```

## Example Usage

```mojo
from regex.engine import match_first

# Basic literal matching
var result = match_first("hello", "hello world")
if result:
    print("Match found:", result.value().match_text)

# Wildcard and quantifiers
result = match_first(".*@.*", "user@domain.com")
if result:
    print("Email found")

# Character ranges
result = match_first("[a-z]+", "hello123")
if result:
    print("Letters:", result.value().match_text)

# Groups and alternation
result = match_first("(com|org|net)", "example.com")
if result:
    print("TLD found:", result.value().match_text)

# Anchors
result = match_first("^https?://", "https://example.com")
if result:
    print("Valid URL")

# Complex patterns
result = match_first("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", "user@example.com")
if result:
    print("Valid email format")
```

## Building and Testing

```bash
# Build the package
./tools/build.sh

# Run tests
./tools/run-tests.sh

# Or run specific test
mojo test -I src/ tests/test_engine.mojo
```

## ❌ TO-DO: Missing Features

### High Priority
- [ ] Global matching (`match_all()`)
- [ ] Non-capturing groups (`(?:...)`)
- [ ] Named groups (`(?<name>...)` or `(?P<name>...)`)
- [ ] Predefined character classes (`\d`, `\w`, `\S`, `\D`, `\W`)
- [ ] Case insensitive matching options
- [ ] Match replacement (`sub()`, `gsub()`)
- [ ] String splitting (`split()`)

### Medium Priority
- [ ] Non-greedy quantifiers (`*?`, `+?`, `??`)
- [ ] Word boundaries (`\b`, `\B`)
- [ ] Match groups extraction and iteration
- [ ] Pattern compilation object
- [ ] Unicode character classes (`\p{L}`, `\p{N}`)
- [ ] Multiline mode (`^` and `$` match line boundaries)
- [ ] Dot-all mode (`.` matches newlines)

### Advanced Features
- [ ] Positive lookahead (`(?=...)`)
- [ ] Negative lookahead (`(?!...)`)
- [ ] Positive lookbehind (`(?<=...)`)
- [ ] Negative lookbehind (`(?<!...)`)
- [ ] Backreferences (`\1`, `\2`)
- [ ] Atomic groups (`(?>...)`)
- [ ] Possessive quantifiers (`*+`, `++`)
- [ ] Conditional expressions (`(?(condition)yes|no)`)
- [ ] Recursive patterns
- [ ] Subroutine calls

### Engine Improvements
- [ ] Performance optimizations
- [ ] Memory usage optimization
- [ ] DFA compilation for simple patterns (hybrid approach with NFA backtracking) to get O(n) in those cases
- [ ] Parallel matching for multiple patterns

## Contributing

Contributions are welcome! If you'd like to contribute, please follow the contribution guidelines in the [CONTRIBUTING.md](CONTRIBUTING.md) file in the repository.

## Acknowledgments

We are heavily inspired by the pure-Python implementation done in the [pyregex](https://github.com/lorenzofelletti/pyregex) library.

## License

mojo-regex is licensed under the [MIT license](LICENSE).
