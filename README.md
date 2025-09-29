# Matrix-Tree in Assembly

A complete implementation of hierarchical matrix structures in x86-64 assembly language, based on the Matrix-Tree concept that embeds trees inside matrices for efficient batch computation.

## 📋 Overview

This project implements the Matrix-Tree data structure entirely in AT&T syntax x86-64 assembly. Each cell of a matrix can contain either:
- **Leaf nodes**: Actual numerical matrix data
- **Internal nodes**: Trees of sub-matrices that can be collapsed or evaluated in parallel

## 🎯 Key Features

- **Pure Assembly Implementation**: Core operations written in x86-64 assembly (AT&T syntax)
- **Hierarchical Storage**: Nested tree structures for efficient reuse
- **Dual Evaluation Modes**:
  - **Collapsed Mode**: Sum all sub-matrices into one result
  - **Batch Mode**: Matrix-vector multiplication with collapsed representation
- **Memory Management**: Full malloc/free integration for dynamic allocation
- **SIMD-Ready**: Uses SSE2 instructions for floating-point operations

## 📁 Files

- `matrix_tree.asm` - Core assembly implementation (~600 lines)
- `matrix_tree.h` - C header for interfacing with assembly
- `demo.c` - Demonstration program with examples
- `Makefile` - Build configuration

## 🔧 Building

```bash
make demo
./demo
```

**Requirements:**
- GCC with x86-64 support
- GNU Assembler (as)
- Linux environment (tested on Ubuntu 24)

## 🏗️ Data Structure

```
TreeNode (32 bytes):
  +0:  node_type    (8 bytes) - 0=leaf, 1=internal
  +8:  rows         (4 bytes)
  +12: cols         (4 bytes)
  +16: data_ptr     (8 bytes) - matrix data or children array
  +24: num_children (8 bytes)
```

### Leaf Node
Stores actual matrix data as row-major double-precision floats.

### Internal Node
Stores pointers to child nodes, which are collapsed via summation.

## 🚀 API Functions

### Core Operations

```c
// Create a new matrix tree node
MatrixTreeNode* matrix_tree_create(
    uint32_t rows,
    uint32_t cols, 
    uint64_t node_type
);

// Recursively destroy node and children
void matrix_tree_destroy(MatrixTreeNode* node);

// Set data for a leaf node
int matrix_tree_set_leaf(
    MatrixTreeNode* node,
    const double* data,
    size_t data_size
);

// Set children for an internal node  
int matrix_tree_set_internal(
    MatrixTreeNode* node,
    MatrixTreeNode** children,
    uint64_t num_children
);
```

### Mathematical Operations

```c
// Collapse tree by summing all leaves
int matrix_tree_collapse(
    MatrixTreeNode* node,
    double* output
);

// Matrix-vector multiplication: y = A*x
int matrix_tree_multiply_collapsed(
    MatrixTreeNode* node,
    const double* x,
    double* y
);

// Scale all matrices by scalar: A' = s*A
void matrix_tree_scale(
    MatrixTreeNode* node,
    double scalar
);
```

## 💡 Usage Examples

### Example 1: Basic Leaf Matrix

```c
double data[] = {1.0, 2.0, 3.0, 4.0};
MatrixTreeNode* leaf = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
matrix_tree_set_leaf(leaf, data, sizeof(data));

// Use the matrix...

matrix_tree_destroy(leaf);
```

### Example 2: Matrix-Vector Multiplication

```c
double matrix_data[] = {
    1.0, 2.0, 3.0,
    4.0, 5.0, 6.0,
    7.0, 8.0, 9.0
};

MatrixTreeNode* A = matrix_tree_create(3, 3, NODE_TYPE_LEAF);
matrix_tree_set_leaf(A, matrix_data, sizeof(matrix_data));

double x[] = {1.0, 2.0, 3.0};
double y[3];

matrix_tree_multiply_collapsed(A, x, y);
// Result: y = [14.0, 32.0, 50.0]

matrix_tree_destroy(A);
```

### Example 3: Hierarchical Tree Structure

```c
// Create three leaf matrices
double d1[] = {1.0, 0.0, 0.0, 1.0};  // Identity
double d2[] = {2.0, 0.0, 0.0, 2.0};  // 2*Identity
double d3[] = {0.5, 0.0, 0.0, 0.5};  // 0.5*Identity

MatrixTreeNode* leaf1 = create_leaf_with_data(2, 2, d1);
MatrixTreeNode* leaf2 = create_leaf_with_data(2, 2, d2);
MatrixTreeNode* leaf3 = create_leaf_with_data(2, 2, d3);

// Create internal node combining all three
MatrixTreeNode* internal = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
MatrixTreeNode* children[] = {leaf1, leaf2, leaf3};
matrix_tree_set_internal(internal, children, 3);

// Collapse to get sum
double output[4];
matrix_tree_collapse(internal, output);
// Result: [3.5, 0.0; 0.0, 3.5]

matrix_tree_destroy(internal);  // Also destroys children
```

### Example 4: Scaling

```c
MatrixTreeNode* matrix = create_leaf_with_data(2, 2, data);

matrix_tree_scale(matrix, 2.5);
// All elements multiplied by 2.5

matrix_tree_destroy(matrix);
```

## 🏛️ Architecture

### Register Usage (x86-64 System V ABI)

**Preserved (callee-saved):**
- `%rbx`, `%rbp`, `%r12-r15` - Saved/restored by assembly functions
- Stack pointer aligned to 16 bytes

**Arguments:**
- `%rdi, %rsi, %rdx, %rcx, %r8, %r9` - Integer/pointer arguments
- `%xmm0-xmm7` - Floating-point arguments

### Memory Management

All dynamic allocations use libc `malloc`/`free` through PLT:
- Node structures: `malloc(32)`
- Matrix data: `malloc(rows * cols * 8)`
- Children arrays: `malloc(num_children * 8)`

### Floating-Point Operations

Uses SSE2 instructions for double-precision:
- `movsd` - Load/store doubles
- `addsd` - Add doubles
- `mulsd` - Multiply doubles
- `xorpd` - Zero XMM registers

## 🔍 Technical Details

### Collapse Algorithm

Recursively traverses the tree structure:
1. If leaf: copy data to output
2. If internal:
   - Zero output buffer
   - Collapse each child into temp buffer
   - Element-wise add temp to output

### Matrix-Vector Multiplication

1. Collapse tree to temporary buffer
2. For each row i:
   - Compute dot product of row i with vector x
   - Store result in y[i]

### Scaling

Recursively applies scalar multiplication:
- Leaf nodes: multiply all elements by scalar
- Internal nodes: recursively scale all children

## ⚠️ Build Notes

**Linker Warning:** The warning about missing `.note.GNU-stack` section is expected and doesn't affect functionality. To suppress:

```asm
.section .note.GNU-stack,"",@progbits
```

Add to end of `matrix_tree.asm` if desired.

## 🎓 Educational Value

This implementation demonstrates:
- **Assembly Programming**: Complex data structures and algorithms
- **ABI Compliance**: Proper x86-64 System V calling conventions
- **Memory Management**: Dynamic allocation in assembly
- **Recursive Algorithms**: Tree traversal in assembly
- **Floating-Point**: SSE2 numeric computation
- **C Interop**: Calling C library functions from assembly

## 🔬 Testing

The demo program includes tests for:
- Basic leaf node creation and display
- Matrix-vector multiplication
- Tree collapse operations
- Hierarchical structures

Run with:
```bash
./demo
```

Expected output shows all operations working correctly with numerical results.

## 📊 Performance Characteristics

- **Tree Traversal**: O(n) where n = number of nodes
- **Collapse**: O(mn) where m = matrix size, n = number of leaves
- **Matrix-Vector**: O(rows × cols) after collapse
- **Memory**: O(total matrix elements + tree structure overhead)

## 🔮 Future Enhancements

Potential extensions mentioned in the original concept:
- **Fused Batch Mode**: Evaluate multiple scenarios simultaneously
- **GPU Kernels**: CUDA/ROCm implementations
- **Symbolic Operations**: Non-numeric merge operations
- **Parallel Evaluation**: Multi-threaded tree traversal
- **Advanced Operators**: Min, max, block-diagonal merging

## 📝 License

This is an educational implementation. Feel free to use and modify for learning purposes.

## 🙏 Acknowledgments

Based on the Matrix-Tree concept described in the provided documentation, which explores embedding trees inside matrices for flexible computation patterns.

---

**Note**: This implementation prioritizes clarity and correctness over maximum performance. Production use would benefit from additional optimizations like SIMD vectorization, cache-aware algorithms, and parallel processing.
