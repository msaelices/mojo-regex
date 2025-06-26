# Contributing to mojo-regex

Thank you for your interest in contributing to mojo-regex! This guide will help you understand the project structure, development workflow, and contribution guidelines.

## Architecture Overview

The mojo-regex library follows a traditional regex engine architecture with clear separation of concerns:

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
   ⚙️ Engine (engine.mojo)
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

#### 5. **Engine** (`src/regex/engine.mojo`)
- **Purpose**: Executes pattern matching with backtracking NFA
- **Algorithm**: Recursive backtracking with greedy matching
- **Key functions**: `match_first()`, `match_node()`, `match_quantified()`
- **Features**: Position tracking, match text extraction

### Data Flow Example

```mojo
// Input: "a*b+"
// 1. Lexer produces: [Element('a'), Asterisk(), Element('b'), Plus()]
// 2. Parser produces: RE -> [ELEMENT('a'), quantified(*), ELEMENT('b'), quantified(+)]
// 3. Engine matches against text using backtracking
```

### Implementation Patterns

- **Functional approach**: Most functions are pure with clear inputs/outputs
- **Error handling**: Uses Mojo's `raises` for parsing errors
- **Memory management**: Uses Mojo's ownership system and List/Deque collections
- **Performance**: Optimized for common patterns while maintaining flexibility

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
- `tests/test_engine.mojo` - Main integration tests with 32+ test cases

### Running Specific Tests
```bash
# Test a specific module
mojo test -I src/ tests/test_lexer.mojo
mojo test -I src/ tests/test_parser.mojo
mojo test -I src/ tests/test_engine.mojo

# Test all
./tools/run-tests.sh
```

### Adding Tests
When contributing new features:
1. Add unit tests for the specific module
2. Add integration tests in `test_engine.mojo`
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

### Current Implementation
- **Engine type**: NFA with backtracking
- **Time complexity**: O(n) to O(2^n) depending on pattern
- **Space complexity**: O(n) for most patterns

### Optimization Guidelines
- Profile before optimizing
- Focus on common use cases first
- Consider algorithmic improvements (DFA compilation)
- Maintain correctness while improving performance

## Getting Help

- **GitHub Issues**: For bugs, feature requests, and discussions
- **Code Review**: All contributions go through review process
- **Architecture Questions**: Reference this document and existing code patterns

## Code of Conduct

Please be respectful and constructive in all interactions. This project follows standard open-source community guidelines for inclusive and collaborative development.

---

Thank you for contributing to mojo-regex! Your efforts help make regex processing in Mojo better for everyone. 🙏
