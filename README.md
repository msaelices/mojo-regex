# Regex
Regular Expressions Library for Mojo

`mojo-regex` is a regex library featuring a hybrid DFA/NFA/PikeVM/LazyDFA engine architecture that automatically optimizes pattern matching based on complexity.

It aims to provide a similar interface as the [re](https://docs.python.org/3/library/re.html) stdlib package while leveraging Mojo's performance capabilities.

Beats Python's C-based `re` module on 96% of benchmarks. Beats Rust's `regex` crate on 61%.

## Installation

1. **Install [pixi](https://pixi.sh/latest/)**

2. **Add the Package** (at the top level of your project):

    ```bash
    pixi add mojo-regex
    ```

## Example Usage

```mojo
from regex import match_first, findall, search, sub

# Basic matching
var result = match_first("hello", "hello world")
if result:
    print("Match found:", result.value().get_match_text())

# Character classes and quantifiers
result = match_first("[a-z]+\\d+", "item42")

# Find all matches
var numbers = findall("\\d+", "Price: $123, Quantity: 456")
for i in range(len(numbers)):
    print("Number:", numbers[i].get_match_text())

# Pattern substitution (re.sub equivalent)
var cleaned = sub("\\s+", " ", "hello   world")
print(cleaned)  # "hello world"

# Capture group interpolation
var formatted = sub("(\\d{3})(\\d{3})(\\d{4})", "\\1-\\2-\\3", "6502530000")
print(formatted)  # "650-253-0000"
```

## Performance

See [benchmarks/results/comparison.md](benchmarks/results/comparison.md) for detailed results across 80 benchmarks comparing Mojo, Python, and Rust.

## Building and Testing

```bash
# Run tests
pixi run test

# Run benchmarks
pixi run mojo run -I src benchmarks/bench_engine.mojo
```

## Missing Features

- Named groups (`(?<name>...)`)
- Case insensitive matching
- String splitting (`split()`)
- Non-greedy quantifiers (`*?`, `+?`, `??`)
- Word boundaries (`\b`, `\B`)
- Unicode character classes (`\p{L}`, `\p{N}`)
- Multiline mode, dot-all mode
- Lookahead / lookbehind
- Negated predefined classes (`\S`, `\D`, `\W`)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture overview, development setup, and guidelines.

## License

MIT. See [LICENSE](LICENSE).

---

[![Language](https://img.shields.io/badge/language-mojo-orange)](https://www.modular.com/mojo)
[![License](https://img.shields.io/github/license/msaelices/mojo-regex?logo=github)](https://github.com/msaelices/mojo-regex/blob/main/LICENSE)
[![Contributors Welcome](https://img.shields.io/badge/contributors-welcome!-blue)](https://github.com/msaelices/mojo-regex#contributing)
![CodeQL](https://github.com/msaelices/mojo-regex/workflows/CodeQL/badge.svg)
