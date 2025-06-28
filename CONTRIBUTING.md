# Contributing to mojo-regex

Thank you for your interest in contributing to mojo-regex! This guide will help you understand the project structure, development workflow, and contribution guidelines.

## Architecture Overview

The mojo-regex library uses a hybrid DFA/NFA architecture with intelligent pattern routing for optimal performance:

### Core Components

```
   Input Regex String
       ↓
   📝 Lexer (lexer.mojo)
       ↓
   🔣 Tokens (tokens.mojo)
       ↓
   🌳 Parser (parser.mojo)
       ↓
   🎯 AST (ast.mojo)
       ↓
   🧠 Optimizer (optimizer.mojo)
       ↓
   🔀 HybridMatcher (matcher.mojo)
      ├─ 🏎️ DFA Engine (O(n) for simple patterns)
      └─ 🔄 NFA Engine (backtracking for complex patterns)
       ↓
   📊 Match Results
```

#### 1. **Lexer** (`src/regex/lexer.mojo`)
- **Purpose**: Tokenizes regex strings into a stream of tokens
- **Input**: Raw regex string (e.g., `"a*b+"`)
- **Output**: List of tokens (e.g., `[Element('a'), Asterisk(), Element('b'), Plus()]`)
- **Key function**: `scan(regex: String) -> List[Token]`

#### 2. **Tokens** (`src/regex/tokens.mojo`)
- **Purpose**: Defines all regex token types and their properties
- **Contains**: 27+ token types including `ELEMENT`, `WILDCARD`, `QUANTIFIER`, `ANCHOR`, etc.
- **Key structures**: `Token` struct with type constants and factory functions

#### 3. **Parser** (`src/regex/parser.mojo`)
- **Purpose**: Builds an Abstract Syntax Tree (AST) from tokens
- **Input**: List of tokens from lexer
- **Output**: AST representing the regex pattern structure
- **Key functions**: `parse()`, `parse_token_list()` for recursive parsing
- **Handles**: Precedence, grouping, quantifiers, alternation

#### 4. **AST** (`src/regex/ast.mojo`)
- **Purpose**: Represents regex patterns as tree structures
- **Node types**: `RE`, `ELEMENT`, `WILDCARD`, `SPACE`, `RANGE`, `START`, `END`, `OR`, `GROUP`
- **Key functions**: `is_match()`, `is_leaf()`, node factory functions
- **Supports**: Quantifiers, capturing groups, character ranges

#### 5. **Optimizer** (`src/regex/optimizer.mojo`)
- **Purpose**: Analyzes patterns to determine optimal execution strategy
- **Input**: AST from parser
- **Output**: Pattern complexity classification (`SIMPLE`, `MEDIUM`, `COMPLEX`)
- **Key functions**: `analyze_pattern()`, `get_pattern_complexity()`

#### 6. **Hybrid Matcher** (`src/regex/matcher.mojo`)
- **Purpose**: Intelligent routing between DFA and NFA engines
- **Strategy**: Uses DFA for simple patterns (O(n)), NFA for complex ones
- **Key structures**: `HybridMatcher`, `DFAMatcher`, `NFAMatcher`
- **Benefits**: Best-case O(n) performance while maintaining full regex support

#### 7. **DFA Engine** (`src/regex/dfa.mojo`)
- **Purpose**: Deterministic finite automaton for simple patterns
- **Algorithm**: O(n) pattern matching with state transitions
- **Optimizations**: SIMD character class matching, Boyer-Moore for literals
- **Ideal for**: Literal strings, simple quantifiers, character classes

#### 8. **NFA Engine** (`src/regex/nfa.mojo`)
- **Purpose**: Non-deterministic finite automaton with backtracking
- **Algorithm**: Recursive backtracking with greedy matching
- **Key functions**: `match_first()`, `match_node()`, `match_quantified()`
- **Features**: Full regex support including groups, alternation, complex patterns

### Data Flow Example

```mojo
// Input: "hello" (simple literal pattern)
// 1. Lexer produces: [Element('h'), Element('e'), Element('l'), Element('l'), Element('o')]
// 2. Parser produces: RE -> [ELEMENT('h'), ELEMENT('e'), ELEMENT('l'), ELEMENT('l'), ELEMENT('o')]
// 3. Optimizer classifies as SIMPLE pattern
// 4. HybridMatcher routes to DFA engine for O(n) matching

// Input: "a*b+" (quantified pattern)
// 1. Lexer produces: [Element('a'), Asterisk(), Element('b'), Plus()]
// 2. Parser produces: RE -> [ELEMENT('a'), quantified(*), ELEMENT('b'), quantified(+)]
// 3. Optimizer classifies as MEDIUM pattern
// 4. HybridMatcher may use DFA (if supported) or fallback to NFA
```

### Implementation Patterns

- **Functional approach**: Most functions are pure with clear inputs/outputs
- **Error handling**: Uses Mojo's `raises` for parsing errors
- **Memory management**: Uses Mojo's ownership system and List collections with zero-copy optimizations
- **Performance**: Hybrid DFA/NFA approach optimizes common patterns (O(n)) while maintaining full regex support
- **SIMD integration**: Uses vectorized operations for character class matching and string search

## Development Setup

### Prerequisites
- [Mojo](https://docs.modular.com/mojo/manual/get-started) development environment
- [pixi](https://pixi.sh/) package manager

### Quick Start

1. **Activate the development environment**:
```bash
pixi shell
```

2. **Set up pre-commit hooks**:
```bash
pre-commit install
```

3. **Build the package**:
```bash
./tools/build.sh
```

4. **Run tests**:
```bash
./tools/run-tests.sh
```

5. **Run benchmarks**:
```bash
mojo benchmarks/bench_engine.mojo
```

## Testing

### Test Structure
- `tests/test_*.mojo` - Comprehensive test suites for each module
- `tests/test_matcher.mojo` - Main integration tests covering both DFA and NFA engines
- `tests/test_nfa.mojo` - NFA-specific tests for complex patterns

### Running Specific Tests
```bash
# Test a specific module
mojo test -I src/ tests/test_lexer.mojo
mojo test -I src/ tests/test_parser.mojo
mojo test -I src/ tests/test_matcher.mojo
mojo test -I src/ tests/test_nfa.mojo

# Test all
./tools/run-tests.sh
```

### Adding Tests
When contributing new features:
1. Add unit tests for the specific module
2. Add integration tests in `test_matcher.mojo` for both DFA and NFA paths
3. Ensure all existing tests continue to pass
4. Add performance benchmarks if applicable

## Contribution Areas
Check the TO-DO section in the README for current feature requests and improvements. Contributions are welcome.

## Code Style Guidelines

### General Principles
1. **Follow existing patterns** in the codebase
2. **Use descriptive names** for functions and variables
3. **Add comprehensive docstrings** for public functions
4. **Handle errors gracefully** using Mojo's error system
5. **Write tests** for all new functionality

### Naming Conventions
- **Functions**: `snake_case` (e.g., `match_first`, `parse_token_list`)
- **Structs**: `PascalCase` (e.g., `ASTNode`, `Token`)
- **Constants using aliases**: `UPPER_CASE` (e.g., `ELEMENT`, `WILDCARD`)
- **Files**: `snake_case.mojo` (e.g., `test_engine.mojo`)

### Documentation
- Use triple-quoted docstrings for functions
- Include `Parameters:` and `Args:` sections as appropriate
- Provide usage examples for complex functions
- Document algorithm complexity where relevant

## Performance Considerations

### Hybrid Architecture Benefits
- **DFA Engine**: O(n) time complexity for simple patterns (literals, basic quantifiers, character classes)
- **NFA Engine**: O(n) to O(2^n) for complex patterns with full regex feature support
- **Smart Routing**: Optimizer automatically selects optimal engine based on pattern complexity
- **SIMD Acceleration**: Vectorized operations for character matching and string search

### Performance Guidelines
- **Simple patterns** (literals, anchors, basic quantifiers): Automatically use DFA for O(n) performance
- **Medium patterns** (groups, alternations): May use optimized DFA or fallback to NFA
- **Complex patterns** (backreferences, lookahead): Use NFA with optimized backtracking

### Optimization Guidelines
- Profile before optimizing
- Use pattern complexity analyzer to understand engine selection
- Focus on common use cases first - DFA handles most real-world patterns efficiently
- Consider SIMD-friendly character class representations
- Maintain correctness while improving performance

### Benchmarking
Use the comprehensive benchmark suite to measure performance:
```bash
mojo benchmarks/bench_engine.mojo
```
This covers literal matching, wildcards, quantifiers, character ranges, anchors, alternation, and groups.

## Getting Help

- **GitHub Issues**: For bugs, feature requests, and discussions
- **Code Review**: All contributions go through review process
- **Architecture Questions**: Reference this document and existing code patterns

## Code of Conduct

Please be respectful and constructive in all interactions. This project follows standard open-source community guidelines for inclusive and collaborative development.

---

Thank you for contributing to mojo-regex! Your efforts help make regex processing in Mojo better for everyone. 🙏
