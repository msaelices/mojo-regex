## Mojo🔥 GPU Programming Workshop

<div style="text-align: center;">
<img src="./image/workshop.png" alt="workshop" width="700" height="400">
</div>

---

# Workshop Agenda

### Part 1: Foundations

**1. Why Mojo🔥?**
<!-- .element: class="fragment" data-fragment-index="1" -->

**2. Setup Using [Pixi](https://pixi.sh/latest/)**
<!-- .element: class="fragment" data-fragment-index="2" -->

**3. Introduction to Mojo🔥 for GPU Programming**
<!-- .element: class="fragment" data-fragment-index="3" -->

### Part 2: Practical Implementation

**4. Hands-on GPU Programming in Mojo**
<!-- .element: class="fragment" data-fragment-index="4" -->

**5. Create your Own AI Model with MAX🧑‍🚀**
<!-- .element: class="fragment" data-fragment-index="5" -->

**6. PyTorch Integration**
<!-- .element: class="fragment" data-fragment-index="6" -->

---

# 📚 Resources

- **Modular OSS Repository** [https://github.com/modular/modular](https://github.com/modular/modular)

- **Introduction to GPU Programming in Mojo🔥**
[https://docs.modular.com/mojo/manual/gpu/architecture](https://docs.modular.com/mojo/manual/gpu/architecture)

- **Mojo🔥 GPU Puzzles** [github.com/modular/mojo-gpu-puzzles](https://github.com/modular/mojo-gpu-puzzles)

- **🤖AI Coding Assistance Guide** [https://docs.modular.com/max/coding-assistants/](https://docs.modular.com/max/coding-assistants/)

- **✅Forum** [forum.modular.com](https://forum.modular.com/)

---

<!-- .slide: class="center-slide" -->
# Part 1: Foundations

---

### Why Mojo🔥?

- 🤝 **Heterogenous _System_ Programming Language**
- 🐍 **Python-like Syntax**
- ⚡ **Zero-cost Abstractions**
- 🛡️ **Strong Type System**
- 🦀 **Memory Safety**

---

### Performance Benefits

- 📊 **Built-in SIMD Support**
- 🔧 **Direct Hardware Access**
- 🔄 **Cross-Hardware Portability**

_Combining the best of Python, C++, and Swift/Rust_

Note: Mojo represents a paradigm shift in systems programming, making GPU programming accessible without sacrificing performance.

---

<!-- .slide: class="center-slide" -->

# GPU Programming

## Traditional vs Mojo🔥

---

### ❌ Traditional CUDA Pain Points

**Complex and Error-Prone**

```cpp
// Manual memory management, verbose boilerplate
int *d_a, *d_b, *d_c;
cudaMalloc(&d_a, size * sizeof(int));
cudaMalloc(&d_b, size * sizeof(int));
cudaMemcpy(d_a, h_a, size * sizeof(int), cudaMemcpyHostToDevice);
vector_add<<<grid, block>>>(d_a, d_b, d_c);
cudaDeviceSynchronize();
cudaFree(d_a); cudaFree(d_b); cudaFree(d_c);
```

⚠️ **Manual memory management • Verbose syntax • Error-prone**

---

### ✅ Mojo🔥 Elegance

**Python Simplicity, C++ Performance**

```mojo
ctx = DeviceContext()
a = ctx.enqueue_create_buffer[dtype](size)
b = ctx.enqueue_create_buffer[dtype](size)
c = ctx.enqueue_create_buffer[dtype](size)
ctx.enqueue_function[vector_add[dtype, size]](
    a.unsafe_ptr(), b.unsafe_ptr(), c.unsafe_ptr(),
    grid_dim=blocks, block_dim=threads
)
ctx.synchronize()
```

✨ **Automatic memory management • Clean syntax • Type-safe**

---

<!-- .slide: class="center-slide" -->
## Mojo🔥 GPU Advantages

## Built for Modern Development

---

### Development Features

- 🚀 **Direct hardware access** with Python ergonomics
- 🔧 **Built-in GPU types**: `DeviceContext`, `LayoutTensor`
- 💾 **Automatic memory management** with ASAP destruction

---

### Performance Features

- ⚡ **Async operations** between CPU and GPU
- 🎯 **Thread-safe by design** for massive parallelism
- 📈 **Compile-time optimizations** for peak performance

---


## Setup Using Pixi

### Prerequisites

- 📖 **Documentation**: [docs.modular.com/max/get-started](https://docs.modular.com/max/get-started)

- **OS Support:**
  - Linux/Ubuntu 22.04+
  - macOS 13+
  - Windows WSL2

- **Python: >=3.9, < 3.13**

- **[Compatible GPUs](https://docs.modular.com/max/faq/#gpu-requirements)**
  - Tier 1: NVIDIA H100/200, A100/A10, L4/L40 and AMD MI300X and MI325X
  - Tier 2: NVIDIA RTX 40XX/30XX series
  - Tier 3: Check the documentation

---

## 🛠️ Installation Steps

```bash
# Install Pixi
curl -fsSL https://pixi.sh/install.sh | sh
```

```bash
# Create a new project
pixi init quickstart \
    -c https://conda.modular.com/max-nightly/ -c conda-forge \
    && cd quickstart
```

```bash
# Add MAX that includes Mojo
pixi add max

# Verify installation
pixi run mojo --version
```

🔍 **Environment Check**: Follow along - we'll troubleshoot together!

Note: Make sure everyone has their environment working before we proceed to coding.

---

### VS Code Extension

Be sure to use the [nightly VSCode
extension](https://marketplace.visualstudio.com/items?itemName=modular-mojotools.vscode-mojo-nightly)
instead of the stable extension. That will ensure that you're using the latest
version to give you the best experience.

<div style="text-align: center;">
<img src="./image/nightly.jpg" alt="nightly" width="900" >
</div>

---


<!-- .slide: class="center-slide" -->
# Introduction to Mojo🔥

### Essentials for GPU Programming

---

### 🧠 Core Language Concepts

```mojo
# `main` function is the entry point of the program
fn main():
    print("Hello, World!")

# Basic function
fn add(a: Int32, b: Int32) -> Int32:
    return a + b

# Parametric function: `param` is known at compile-time
fn kernel[size: Int, dtype: DType](data: UnsafePointer[dtype]):
    # Parameters drive GPU performance
```

⚠️ **Key Point**: `fn` functions are strict, essential for GPU kernels (no exceptions allowed)

---

### Python Compatible `def` Function

```mojo
def main():
    try:
        ...
    except:
        raise Error("Exception occured!")

# equivalent to

fn main() raises:
    try:
        ...
    except:
        raise Error("Exception occured!")
```

---

### Variable Declaration

- Python-like

```mojo
a = 42
```

- The use of `var` is mostly optional but is required for type-checking

```mojo
var a: UInt128 = 42
# Same as
a = UInt128(42)
```

---

### Function Types Comparison

- **`fn` Functions:**
  - ✅ **Strict and Safe**
  - No exceptions by default
  - Required for GPU kernels

- **`def` Functions:**
  - 🐍 **Python Compatible**
  - Can raise exceptions
  - More flexible
  - Runtime behavior
  - Interop friendly

🔥 **GPU Rule**: Use `fn` for kernels - GPU hardware cannot handle exceptions!

---

### Type System Highlights

- `Int32/64` is a 32/64-bit integer
- `Float32/64` is a 32/64-bit floating point number
- `Bool` is a boolean
- `String` is a string
- `List[T]` is a list of type `T`
- `Pointer[T]` is a safe (non-null) pointer to type `T`
- `UnsafePointer[T]` is an unsafe pointer to type `T`
- `SIMD[DType, width: Int]` is a SIMD vector

---

<!-- .slide: class="center-slide" -->
`Float32` = `Scalar[DType.float32]` = `SIMD[DType.float32, 1]`

```mojo
# compile-time constant
alias size = 4
# SIMD types for vectorization
vector = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)

# Memory management
ptr = UnsafePointer[Float32].alloc(1000)
# Explicit cleanup
ptr.free()
```

⚡ **Performance Tip**: SIMD types unlock vectorization for massive parallelism!

---

### Structs

```mojo
struct Vector3D:
    var x: Float32
    var y: Float32
    var z: Float32

    fn __init__(out self, x: Float32, y: Float32, z: Float32):
        self.x = x
        self.y = y
        self.z = z

    fn magnitude(self) -> Float32:
        return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
```

---

### Conditional Statements

```mojo
fn check_value(x: Int32) -> String:
    if x > 0:
        return "positive"
    elif x < 0:
        return "negative"
    else:
        return "zero"
```

---

### Loops with `for` and `while`

```mojo
fn iterate_example():
    for i in range(5):
        print(i)

    count = 0
    while count < 3:
        print("count:", count)
        count += 1
```

---

### Break and Continue

```mojo
fn loop_control():
    for i in range(10):
        if i == 3:
            continue  # Skip iteration
        if i == 7:
            break     # Exit loop
        print(i)
```

💡 **GPU Note**: Control flows in kernels should be minimized for optimal performance!

---


### Compile Time Optimizations

#### Parameters and the `@parameter for` decorator

Mojo structs and functions can take parameters. `@parameter` annotations denote
compile-time evaluation, like explicit loop unrolling:

```mojo
fn repeat[count: Int](msg: String):
    @parameter
    for i in range(count):
        print(msg)

repeat[3]("Hello")
```

```bash
Hello
Hello
Hello
```

---

### Compile Time Optimizations

#### `@parameter if` decorator

```mojo
@parameter
if True:
    print("this will be included in the binary")
else:
    print("this will be eliminated at compile time")
```

---

### Compile Time Specialization

"Generics" refers to functions that can act on multiple types of values, or
containers that can hold multiple types of values. For example, SIMD, can hold
different data types/widths.

```mojo
struct SIMD[type: DType, size: Int]:
    var value: … # Some low-level MLIR stuff here

    # Many standard operators are supported.
    fn __mult__(self, rhs: Self) -> Self: ...

```

```
var vector = SIMD[DType.int16, 4](1, 2, 3, 4)
vector = vector * vector
for i in range(4):
    print(vector[i], end=" ")
```

```bash
1 4 9 16
```

---

### Key Takeaways

🔥 **`fn` for kernels** (no exceptions)

⚡ **SIMD types** Vectorization

🏗️ **Structs** for Data Structures

> Note: These fundamentals are crucial - they enable the performance characteristics that make Mojo special for CPU/GPU programming.

---

<!-- .slide: class="center-slide" -->
# Part 2: Practical Implementation

---

<!-- .slide: class="center-slide" -->
## Hands-on GPU Programming with Mojo🔥

---

### Clone the Mojo🔥 GPU Puzzles

```bash
git clone https://github.com/modular/mojo-gpu-puzzles
cd mojo-gpu-puzzles
```

Make sure you've Pixi installed. See [https://prefix.dev/](https://prefix.dev/)

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

🌐 **Online Version**: [builds.modular.com/puzzles](https://builds.modular.com/puzzles)

📝 **Note**: Extensive use in Part 2!

---

<!-- .slide: class="center-slide" -->
## GPU Programming Fundamentals

---

<div style="display: flex; align-items: flex-start; gap: 40px;">
<div style="flex: 1;">

### GPU vs CPU Architecture
- **CPUs**: Few powerful cores optimized for sequential processing and complex decision making
- **GPUs**: Thousands of smaller, simpler cores designed for parallel processing
- **Complementary**: CPU handles program flow and complex logic, GPU handles parallel computations

</div>
<div style="flex: 0 0 500px;">
<img src="./image/cpu-gpu-architecture.png" alt="CPU vs GPU Architecture" width="500" height="400" style="border-radius: 5px;">
</div>
</div>

---

### GPU Hardware Components

<img src="./image/sm-architecture.png" alt="SM Architecture" width="1000" height="400" style="border-radius: 5px;">

---

### GPU Hardware Components

- **Streaming Multiprocessors (SMs)**: Self-contained processing factories that operate independently
- **CUDA Cores/Stream Processors**: Basic arithmetic units performing calculations
- **Tensor/Matrix Cores**: Specialized units for matrix multiplication and AI operations
- **Register Files**: Ultra-fast storage for thread-specific data
- **Shared Memory/L1 Cache**: Low-latency memory for data sharing between threads

---

### GPU Execution Model

<img src="./image/grid-hierarchy.png" alt="Grid hierarchy" width="700" height="600" style="border-radius: 5px;">

---

### GPU Execution Model
- **Kernel**: Function that runs on GPU across thousands/millions of threads
- **Grid**: Top-level organization of all threads executing a kernel
- **Thread Blocks**: Groups of threads that can collaborate and share memory
- **Warps**: Subsets of 32-64 threads that execute the same instruction simultaneously
- **SIMT**: Single Instruction, Multiple Threads execution model

---

### Key Performance Concepts
- **Warp Divergence**: Performance penalty when threads in a warp take different paths
- **Memory Coalescing**: Efficient memory access when threads access contiguous locations
- **Thread Block Sizing**: Should be multiples of warp size for optimal resource usage
- **Latency Hiding**: GPU switches between warps to hide memory access delays

---

### Your First Kernel

Print block and thread ids for `grid_dim=2` and `block_dim=4`

In `main.mojo`:

```mojo
from gpu import block_idx, thread_idx
from gpu.host import DeviceContext

fn print_threads():
    print("Block index:", block_idx.x, "\t", "Thread index: ", thread_idx.x)

def main():
    # create device context
    ctx = DeviceContext()
    # GPU kernel launches asynchronously - doesn't block Host (CPU)
    ctx.enqueue_function[print_threads](grid_dim=2, block_dim=4)
    # synchronize Host thread with GPU
    ctx.synchronize()
```

---

### Your First Kernel

Run `pixi run mojo main.mojo`

```output
 Block index: 1          Thread index:  0
 Block index: 1          Thread index:  1
 Block index: 1          Thread index:  2
 Block index: 1          Thread index:  3
 Block index: 0          Thread index:  0
 Block index: 0          Thread index:  1
 Block index: 0          Thread index:  2
 Block index: 0          Thread index:  3
```

👁️ Notice the Parallel execution of GPU threads

---

## [🧩Puzzle 1: Map](https://builds.modular.com/puzzles/puzzle_01/puzzle_01.html)

Adds `10` to each position of vector `a` and stores it in vector `output`.

</div>
<div style="flex: 0 0 800px;">
<img src="./gifs/puzzle_01_viz.gif" alt="Puzzle 01" width="800" height="400" style="border-radius: 5px;">
</div>
</div>

---

## [🧩Puzzle 1: Map](https://builds.modular.com/puzzles/puzzle_01/puzzle_01.html)

Adds `10` to each position of vector `a` and stores it in vector `output`.

```mojo
alias SIZE = 4
alias BLOCKS_PER_GRID = 1
alias THREADS_PER_BLOCK = SIZE
alias dtype = DType.float32

fn add_10(
    output: UnsafePointer[Scalar[dtype]], a: UnsafePointer[Scalar[dtype]]
):
    i = thread_idx.x
    # FILL ME IN (roughly 1 line)
```

Run `pixi run p01`

---

## Solution

```mojo
fn add_10(
    output: UnsafePointer[Scalar[dtype]], a: UnsafePointer[Scalar[dtype]]
):
    i = thread_idx.x
    output[i] = a[i] + 10
```

---

## [🧩Puzzle 3: Guards](https://builds.modular.com/puzzles/puzzle_03/puzzle_03.html)

Add `10` to each position of vector `a` and stores it in vector `output`. You have **more threads than positions**.

</div>
<div style="flex: 0 0 800px;">
<img src="./gifs/puzzle_03_viz.gif" alt="Puzzle 03" width="800" height="400" style="border-radius: 5px;">
</div>
</div>

---

## [🧩Puzzle 3: Guards](https://builds.modular.com/puzzles/puzzle_03/puzzle_03.html)

Add `10` to each position of vector `a` and stores it in vector `output`. You have **more threads than positions**.

```mojo
alias SIZE = 4
alias BLOCKS_PER_GRID = 1
alias THREADS_PER_BLOCK = (8, 1)
alias dtype = DType.float32

fn add_10_guard(output: UnsafePointer[Scalar[dtype]],
    a: UnsafePointer[Scalar[dtype]],
    size: Int,
):
    i = thread_idx.x
    # FILL ME IN (roughly 2 lines)
```

Run `pixi run p03`

---

## Solution

```mojo
fn add_10_guard(
    output: UnsafePointer[Scalar[dtype]],
    a: UnsafePointer[Scalar[dtype]],
    size: Int,
):
    i = thread_idx.x
    if i < size:
        output[i] = a[i] + 10.0
```

---

## [🧩Puzzle 4: 2D Map](https://builds.modular.com/puzzles/puzzle_04/puzzle_04.html)

Add `10` to each position of 2D square matrix `a` and stores it in 2D square matrix `output`. Note `a` is row-major i.e. rows are stored in memory.

</div>
<div style="flex: 0 0 800px;">
<img src="./gifs/puzzle_04_viz.gif" alt="Puzzle 04" width="800" height="400" style="border-radius: 5px;">
</div>
</div>

---

<!-- .slide: class="center-slide" -->
## Thread Indexing Convention

</div>
<div style="flex: 0 0 800px;">
<img src="./gifs/thread_indexing_viz.gif" alt="thread indexing" width="800" height="500" style="border-radius: 5px;">
</div>
</div>

---

## [🧩Puzzle 4: 2D Map](https://builds.modular.com/puzzles/puzzle_04/puzzle_04.html)

Add `10` to each position of 2D square matrix `a` and stores it in 2D square matrix `output`. Note `a` is row-major i.e. rows are stored in memory.

```mojo
alias SIZE = 2
alias BLOCKS_PER_GRID = 1
alias THREADS_PER_BLOCK = (3, 3)
alias dtype = DType.float32

fn add_10_2d(
    output: UnsafePointer[Scalar[dtype]],
    a: UnsafePointer[Scalar[dtype]],
    size: Int,
):
    row = thread_idx.y
    col = thread_idx.x
    # FILL ME IN (roughly 2 lines)
```

---

## Solution

Indexing convention:
- `thread_idx.y` corresponds to the row index
- `thread_idx.x` corresponds to the column index

```mojo
fn add_10_2d(
    output: UnsafePointer[Scalar[dtype]],
    a: UnsafePointer[Scalar[dtype]],
    size: Int,
):
    row = thread_idx.y
    col = thread_idx.x
    if row < size and col < size:
        output[row * size + col] = a[row * size + col] + 10.0
```

---

## Why `LayoutTensor`?

Growing challenging with raw `UnsafePointer`

```mojo
# 2D indexing coming in later puzzles
idx = row * WIDTH + col

# 3D indexing
idx = (batch * HEIGHT + row) * WIDTH + col

# With padding
idx = (batch * padded_height + row) * padded_width + col
```

---

## Why `LayoutTensor`?

Idiomatic access `LayoutTensor`:

```mojo
output[i, j] = a[i, j] + 10.0  # 2D indexing
output[b, i, j] = a[b, i, j] + 10.0  # 3D indexing
```

and more advanced features preview:

```mojo
# Column-major layout
layout_col = Layout.col_major(HEIGHT, WIDTH)
# Tiled layout (for better cache utilization)
layout_tiled = tensor.tiled[4, 4](HEIGHT, WIDTH)
# Vectorized access
vec_tensor = tensor.vectorize[1, simd_width]()
# Asynchronous transfers
copy_dram_to_sram_async[thread_layout=layout](dst, src)
# Tensor Core operations (coming in later puzzles)
mma_op = TensorCore[dtype, out_type, Index(M, N, K)]()
result = mma_op.mma_op(a_reg, b_reg, c_reg)
```

---

## How to use `LayoutTensor`?

`LayoutTensor` can be both on CPU and GPU depending on where the underlying data pointer lives.

```mojo
from layout import Layout, LayoutTensor
# Define layout
alias layout = Layout.row_major(2, 3)
# Allocate and initialized memory either on Host (CPU) or Device (GPU)
data_ptr = ...
# Create tensor using the `date_ptr`
tensor = LayoutTensor[mut=True, dtype, layout](data_ptr)
tensor[0, 0] += 1
```

Mojo manual: ["Using LayoutTensor"](https://docs.modular.com/mojo/manual/layout/tensors)

---

## Back to Puzzle 4: 2D Map

**Raw `UnsafePointer` approach:**

```mojo
row = thread_idx.y
col = thread_idx.x
if row < size and col < size:
    output[row * size + col] = a[row * size + col] + 10.0
```

**`LayoutTensor` approach:**

```mojo
row = thread_idx.y
col = thread_idx.x
if row < size and col < size:
    output[row, col] = a[row, col] + 10.0
```

---

## [🧩Puzzle 8: Shared Memory](https://builds.modular.com/puzzles/puzzle_08/puzzle_08.html)

Add `10` to each position of a vector `a` and stores it in vector `output`. You have **fewer threads per block** than the size of `a`.

</div>
<div style="flex: 0 0 800px;">
<img src="./gifs/puzzle_08_viz.gif" alt="Puzzle 08" width="800" height="400" style="border-radius: 5px;">
</div>
</div>

---

## [🧩Puzzle 8: Shared Memory](https://builds.modular.com/puzzles/puzzle_08/puzzle_08.html)

Add `10` to each position of a vector `a` and stores it in vector `output`. You have **fewer threads per block** than the size of `a`.

```mojo
# Allocate shared memory using tensor builder
shared = tb[dtype]().row_major[TPB]().shared().alloc()

global_i = block_dim.x * block_idx.x + thread_idx.x
local_i = thread_idx.x
# Copy local data into shared memory
if global_i < size:
    shared[local_i] = a[global_i]

# wait for all threads to complete works within a thread block
barrier()

# FILL ME IN (roughly 2 lines)
```

---

## Solution

```mojo
# Allocate shared memory using tensor builder
shared = tb[dtype]().row_major[TPB]().shared().alloc()

global_i = block_dim.x * block_idx.x + thread_idx.x
local_i = thread_idx.x

if global_i < size:
    shared[local_i] = a[global_i]
# Copy local data into shared memory
barrier()
# Bound-check and store to global memory
if global_i < size:
    output[global_i] = shared[local_i] + 10
```

---

<!-- .slide: class="center-slide" -->
## Model Development with MAX🧑‍🚀

---

## 📚 Resources

- **Get started with MAX graphs**
[https://docs.modular.com/max/tutorials/get-started-with-max-graph-in-python](https://docs.modular.com/max/tutorials/get-started-with-max-graph-in-python)
- **Build an MLP block as a module**
[https://docs.modular.com/max/tutorials/build-an-mlp-block](https://docs.modular.com/max/tutorials/build-an-mlp-block)
- **Serve custom model architectures**
[https://docs.modular.com/max/tutorials/serve-custom-model-architectures](https://docs.modular.com/max/tutorials/serve-custom-model-architectures)
- **Examples of custom operations**
[https://github.com/modular/modular/tree/main/examples/custom_ops](https://github.com/modular/modular/tree/main/examples/custom_ops)


---

## 🤖 Models in MAX🧑‍🚀

- 🏗️ **Built using the MAX Graph API** - Unified computation framework
- 🐍 **Defined in Python** - Familiar, productive development experience
- ⚡ **Tensor computation graphs** - With lightning-fast Mojo nodes

---

## 🐍 Why Python for MAX Graphs?

**"Best of Both Worlds: Python Productivity + Mojo Performance"**

- 🔗 **Direct integration** with Python's rich ML ecosystem
- 👨‍💻 **Familiar language** to ML engineers and researchers
- 🚀 **Computation time dominated by graph execution** - where Mojo shines!

---

## 🚀 Serving LLMs with MAX

**"Get your AI models running in seconds!"**

```sh
max serve --model-path=Qwen/Qwen2.5-0.5B-Instruct
```

or

```sh
python -m max.entrypoints.pipelines serve \
  --model-path=Qwen/Qwen2.5-0.5B-Instruct
```

📚 **Explore the source**: [github.com/modular/modular](https://github.com/modular/modular/tree/main/max/serve)

---

## 🧪 Testing LLM Text Generation with MAX

**Quick validation of your model deployment**

```sh
max generate --model-path=Qwen/Qwen2.5-0.5B-Instruct --prompt "Hello there."
```

💡 **Pro tip**: Perfect for development testing and demos!

---

## 🧩 MAX Graph Basics

**Core building blocks for high-performance AI**

- 📊 **Graph** (`max.graph`) - Your computation blueprint
- ⚙️ **Graph operations** (`max.graph.ops`) - Mathematical operations
- 🖥️ **Devices** (`max.driver`) - CPU, GPU, accelerator management
- 🎯 **Inference sessions** (`max.engine`) - Optimized execution runtime

---

### 🏗️ Construct a Graph

**Building your first computation graph**

```python
input_type = TensorType(
    dtype=DType.float32, shape=(1,), device=DeviceRef.CPU()
)
with Graph(
    "simple_add_graph", input_types=(input_type, input_type)
) as graph:
    lhs, rhs = graph.inputs
    out = ops.add(lhs, rhs)
    graph.output(out)
```

✨ **Clean, declarative syntax** - Just like you'd expect!

---

### ⚡ Compile and Execute a Graph

**From definition to blazing-fast execution**

```python
session = engine.InferenceSession()
model = session.load(graph)

output = model.execute(a, b)[0]
result = output.to_numpy()
```

🔥 **That's it!** MAX handles all the optimization magic behind the scenes.

---

## 🔧 Graph Operations

**Building blocks for any computation you can imagine**

- 🧱 **Simple atomic operations** - Lower level than other frameworks
- 🚀 **Rely on graph compiler for fusion** - Automatic optimization
- 📖 **Comprehensive library** - Full list at [docs.modular.com/max/api/python/graph/ops](https://docs.modular.com/max/api/python/graph/ops)

```
...
abs()      add()         allgather()    argmax()
argmin()   argsort()     as_interleaved_complex()
...
```

💎 **200+ operations** and growing!

---

## 🧠 `max.nn` Layers

**High-level abstractions for rapid development**

- 🏗️ **Higher-level abstractions** on operations
- 🔄 **Designed to ease porting from PyTorch** - Familiar patterns
- 🚧 **Rapidly expanding** - We're just getting started!
  - 💡 Missing something obvious? **Let us know!**

-> [Translation guide from PyTorch to MAX](https://github.com/modular/modular/blob/main/docs/eng-design/docs/pytorch-to-max-mapping-guide.md)

---

### 🔥 Defining Custom Operations in Mojo

**Unleash maximum performance with custom kernels**

```mojo
@compiler.register("add_one")
struct AddOne:
    @staticmethod
    fn execute[
        target: StaticString,
    ](
        output: OutputTensor,
        x: InputTensor[dtype = output.dtype, rank = output.rank],
        ctx: DeviceContextPtr,
    ) raises:
        @parameter
        @always_inline
        fn elementwise_add_one[
            width: Int
        ](idx: IndexList[x.rank]) -> SIMD[x.dtype, width]:
            return x.load[width](idx) + 1

        foreach[elementwise_add_one, target=target](output, ctx)
```

---

### 🔗 Using Custom Operations in Python Graphs

**Seamless integration: Python🐍 productivity meets Mojo🔥 performance**

```python
mojo_kernels = Path(__file__).parent / "kernels"

device = CPU() if accelerator_count() == 0 else Accelerator()
graph = Graph(
    "addition",
    forward=lambda x: ops.custom(
        name="add_one",
        device=DeviceRef.from_device(device),
        values=[x],
        out_types=[
            TensorType(
                dtype=x.dtype,
                shape=x.tensor.shape,
                device=DeviceRef.from_device(device),
            )
        ],
    )[0].tensor,
    input_types=[
        TensorType(
            dtype,
            shape=[rows, columns],
            device=DeviceRef.from_device(device),
        ),
    ],
    custom_extensions=[mojo_kernels],
)
```

🎯 **Best of both worlds**: Write once in Mojo, use everywhere in Python!

---

## 🏛️ Model Architectures

**Rich ecosystem of pre-built, optimized architectures**

- 🎯 **MAX supports common LLM architectures** - Ready to use out of the box
- 📂 **Open source implementations** - [`modular/max/pipelines/architectures`](https://github.com/modular/modular/tree/main/max/pipelines/architectures)
- 🔍 **Check first, build later** - May already exist or have a close match to modify

💡 **Transformer, Llama, Mistral, Qwen** and many more already supported!

---

## 🚀 Registering and Serving a Model Architecture

**From research to production in 5 steps**

**Tutorial:** ["Serve custom model architectures"](https://docs.modular.com/max/tutorials/serve-custom-model-architectures)

- 📊 **Implement the main model graph** - Define your computation
- ⚙️ **Handle model configuration metadata** - Parameters and settings
- 🗺️ **Map weight names to internal structure** - Connect checkpoints to graph
- 📝 **Register the architecture with MAX** - Make it discoverable
- 🎯 **Load with `--custom-architectures`** - Deploy your custom model

---

<!-- .slide: class="center-slide" -->
## PyTorch Custom Ops Integration (Beta Feature)

### 🚀 Mojo Kernels 🤝 PyTorch Models

---

### Key Benefits

- ⚡ **High-performance kernels** in Mojo🔥
- 🐍 **Familiar PyTorch workflow**
- 🔄 **Seamless integration** - no framework switching
- 🎯 **Target-agnostic** - same code runs on CPU/GPU

---

### Simple Integration

```python
import torch
from max.torch import CustomOpLibrary

# Load compiled Mojo kernels
ops = CustomOpLibrary("./operations")

# Use in PyTorch as normal
@torch.compile
def my_model(x):
    return ops.my_custom_kernel(x)
```

📖 **Tutorial**: [docs.modular.com/max/tutorials/custom-kernels-pytorch](https://docs.modular.com/max/tutorials/custom-kernels-pytorch)

💻 **Code**: [https://github.com/modular/modular/tree/main/examples/pytorch_custom_ops](https://github.com/modular/modular/tree/main/examples/pytorch_custom_ops)

---

### Up for a challenge? ✋

- [🧩 Puzzle 19: Embedding Op](https://builds.modular.com/puzzles/puzzle_19/puzzle_19.html)
- [🧩 Puzzle 20: Kernel Fusion and Custom Backward Pass](https://builds.modular.com/puzzles/puzzle_20/puzzle_20.html)

---

## Using AI coding agents with MAX and Mojo

- When developing new kernels, start inside the root of a `modular` checkout
  - The repository has pre-populated CLAUDE.md and Cursor rules
- For external projects, refer to a `modular` checkout for latest APIs and examples
- Point to our available `llms.txt` for latest documentation
- For more, see ["Using AI coding assistants"](https://docs.modular.com/max/coding-assistants)

---

<!-- .slide: class="center-slide" -->
# Thank You! 🔥

## Questions & Discussion

_Let's build the future of AI programming together!_

Note: Thank you for joining this workshop! Continue learning with the resources provided, and don't hesitate to reach out to the community for support.
