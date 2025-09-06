# Agent Guidelines for mojo-regex

## Build/Test Commands

### Building
```bash
./tools/build.sh
# or
mojo package src/regex -o mojo-regex.mojopkg
```

### Testing
```bash
# Run all tests
./tools/run-tests.sh
# or
mojo test -I src/ tests/

# Run single test file
mojo test -I src/ tests/test_matcher.mojo
# or any specific test: test_lexer.mojo, test_parser.mojo, test_nfa.mojo, etc.
```

### Formatting/Linting
```bash
# Format code
pixi run format
# or
mojo format benchmarks/ src/regex/ tests/

# Pre-commit hooks (includes formatting)
pre-commit run --all-files
```

## Code Style Guidelines

### Naming Conventions
- **Functions**: `snake_case` (e.g., `match_first`, `parse_token_list`)
- **Structs**: `PascalCase` (e.g., `ASTNode`, `Token`)
- **Constants**: `UPPER_CASE` (e.g., `ELEMENT`, `WILDCARD`)
- **Files**: `snake_case.mojo` (e.g., `test_engine.mojo`)

### Documentation
- Use triple-quoted docstrings for all public functions
- Include `Parameters:` and `Args:` sections
- Provide usage examples for complex functions
- Document algorithm complexity where relevant

### Code Structure
- **Functional approach**: Pure functions with clear inputs/outputs
- **Error handling**: Use Mojo's `raises` for parsing errors
- **Memory management**: Leverage Mojo's ownership system and List collections
- **Performance**: Hybrid DFA/NFA architecture with SIMD optimization

### Imports
- Group imports logically (stdlib first, then local modules)
- Use relative imports within the regex package
- Import specific functions/classes rather than entire modules when possible

### Error Handling
- Use Mojo's error system with `raises`
- Provide descriptive error messages
- Handle edge cases gracefully

### Testing
- Write comprehensive tests for all new functionality
- Add both unit tests and integration tests
- Test both DFA and NFA engine paths
- Ensure all existing tests pass before committing
