# Benchmark Suite

This directory contains benchmarks for comparing the performance of the regex library with Python's built-in `re` module.

## Files

- **`bench_engine.mojo`** - Mojo benchmark suite testing the regex library
- **`bench_python_re.py`** - Python benchmark suite testing Python's `re` module
- **`README.md`** - This file

## Running Benchmarks

### Mojo Benchmarks
```bash
# Run the Mojo regex benchmarks
pixi run mojo benchmarks/bench_engine.mojo -t

# Or using mojo directly if installed
mojo benchmarks/bench_engine.mojo -t
```

### Python Benchmarks
```bash
# Run the Python re module benchmarks
python benchmarks/bench_python_re.py

# Or using python3
python3 benchmarks/bench_python_re.py
```


## Performance Comparison

The benchmarks are designed to provide a fair comparison between:

- **Mojo Regex**: Custom implementation optimized for Mojo's performance characteristics
- **Python RE**: Mature, highly optimized C implementation with extensive features

### Key Differences

**Mojo Regex:**
- Pure Mojo implementation
- Compile-time optimizations
- Memory-efficient structures

**Python RE:**
- C implementation (highly optimized)
- Decades of optimization
- Advanced features (lookahead, named groups, etc.)
- Extensive Unicode support

## Interpreting Results

- **Timing**: Lower is better (microseconds/milliseconds)
- **Consistency**: Lower standard deviation indicates more predictable performance
