# Matrix-Tree Usage Examples

This document provides detailed examples of using the Matrix-Tree assembly implementation.

## Quick Start

```bash
# Build the demo
make demo

# Run it
./demo
```

## Example Programs

### Example 1: Simple Matrix Creation

```c
#include "matrix_tree.h"
#include <stdio.h>

int main() {
    // Create a 3x3 identity matrix
    double identity[] = {
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    };
    
    // Create leaf node
    MatrixTreeNode* I = matrix_tree_create(3, 3, NODE_TYPE_LEAF);
    matrix_tree_set_leaf(I, identity, sizeof(identity));
    
    // Print (you'll need to implement print_matrix helper)
    printf("Created 3x3 identity matrix\n");
    
    // Clean up
    matrix_tree_destroy(I);
    return 0;
}
```

### Example 2: Matrix Arithmetic

```c
#include "matrix_tree.h"
#include <stdio.h>

int main() {
    // Create two matrices
    double a_data[] = {1, 2, 3, 4};
    double b_data[] = {5, 6, 7, 8};
    
    MatrixTreeNode* A = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    MatrixTreeNode* B = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    
    matrix_tree_set_leaf(A, a_data, sizeof(a_data));
    matrix_tree_set_leaf(B, b_data, sizeof(b_data));
    
    // Create internal node to represent A + B
    MatrixTreeNode* sum = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* children[] = {A, B};
    matrix_tree_set_internal(sum, children, 2);
    
    // Collapse to get the sum
    double result[4];
    matrix_tree_collapse(sum, result);
    
    printf("A + B = [%.0f %.0f; %.0f %.0f]\n",
           result[0], result[1], result[2], result[3]);
    // Output: A + B = [6 8; 10 12]
    
    matrix_tree_destroy(sum);  // Also destroys A and B
    return 0;
}
```

### Example 3: Solving Linear System (Ax = b)

```c
#include "matrix_tree.h"
#include <stdio.h>

int main() {
    // System: [2 1] [x1]   [5]
    //         [1 3] [x2] = [8]
    // Solution: x1 = 1, x2 = 2 (approximately, for demo purposes)
    
    double A_data[] = {
        2, 1,
        1, 3
    };
    
    MatrixTreeNode* A = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    matrix_tree_set_leaf(A, A_data, sizeof(A_data));
    
    // For demo, we'll just do matrix-vector multiplication
    double x[] = {1.4, 2.2};  // Approximate solution
    double b[2];
    
    matrix_tree_multiply_collapsed(A, x, b);
    
    printf("A*x = [%.1f, %.1f]\n", b[0], b[1]);
    printf("Expected b ≈ [5, 8]\n");
    
    matrix_tree_destroy(A);
    return 0;
}
```

### Example 4: Multi-Scenario Analysis

```c
#include "matrix_tree.h"
#include <stdio.h>

// Analyze system under different parameter scenarios
int main() {
    // Three scenarios: optimistic, baseline, pessimistic
    double optimistic[] = {1.2, 0.1, 0.1, 1.2};
    double baseline[] = {1.0, 0.0, 0.0, 1.0};
    double pessimistic[] = {0.8, -0.1, -0.1, 0.8};
    
    MatrixTreeNode* opt = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    MatrixTreeNode* base = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    MatrixTreeNode* pess = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    
    matrix_tree_set_leaf(opt, optimistic, sizeof(optimistic));
    matrix_tree_set_leaf(base, baseline, sizeof(baseline));
    matrix_tree_set_leaf(pess, pessimistic, sizeof(pessimistic));
    
    // Create tree of scenarios
    MatrixTreeNode* scenarios = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* children[] = {opt, base, pess};
    matrix_tree_set_internal(scenarios, children, 3);
    
    // Collapse to get average scenario
    double avg_scenario[4];
    matrix_tree_collapse(scenarios, avg_scenario);
    
    printf("Average scenario matrix:\n");
    printf("[%.2f %.2f]\n", avg_scenario[0], avg_scenario[1]);
    printf("[%.2f %.2f]\n", avg_scenario[2], avg_scenario[3]);
    
    // Expected: [1.0, 0.0; 0.0, 1.0] (average of three)
    
    matrix_tree_destroy(scenarios);
    return 0;
}
```

### Example 5: Nested Hierarchies

```c
#include "matrix_tree.h"
#include <stdio.h>

// Build a complex hierarchy: ((A + B) + C)
int main() {
    // Create leaf matrices
    double a[] = {1, 0, 0, 1};
    double b[] = {0, 1, 1, 0};
    double c[] = {0.5, 0.5, 0.5, 0.5};
    
    MatrixTreeNode* A = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    MatrixTreeNode* B = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    MatrixTreeNode* C = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    
    matrix_tree_set_leaf(A, a, sizeof(a));
    matrix_tree_set_leaf(B, b, sizeof(b));
    matrix_tree_set_leaf(C, c, sizeof(c));
    
    // Create (A + B)
    MatrixTreeNode* AB = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* ab_children[] = {A, B};
    matrix_tree_set_internal(AB, ab_children, 2);
    
    // Create ((A + B) + C)
    MatrixTreeNode* ABC = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* abc_children[] = {AB, C};
    matrix_tree_set_internal(ABC, abc_children, 2);
    
    // Collapse entire tree
    double result[4];
    matrix_tree_collapse(ABC, result);
    
    printf("((A + B) + C) =\n");
    printf("[%.1f %.1f]\n", result[0], result[1]);
    printf("[%.1f %.1f]\n", result[2], result[3]);
    // Expected: [1.5, 1.5; 1.5, 1.5]
    
    matrix_tree_destroy(ABC);
    return 0;
}
```

### Example 6: Scaling Transformations

```c
#include "matrix_tree.h"
#include <stdio.h>

int main() {
    // Create a transformation matrix
    double rotation[] = {
        0.866, -0.5,   // cos(30°), -sin(30°)
        0.5,    0.866  // sin(30°),  cos(30°)
    };
    
    MatrixTreeNode* R = matrix_tree_create(2, 2, NODE_TYPE_LEAF);
    matrix_tree_set_leaf(R, rotation, sizeof(rotation));
    
    // Scale by 2x
    matrix_tree_scale(R, 2.0);
    
    printf("Scaled rotation matrix by 2x\n");
    printf("(doubles the effect of the transformation)\n");
    
    // Use in computation...
    double point[] = {1.0, 0.0};
    double result[2];
    matrix_tree_multiply_collapsed(R, point, result);
    
    printf("Transformed point: (%.2f, %.2f)\n", result[0], result[1]);
    
    matrix_tree_destroy(R);
    return 0;
}
```

## Building Custom Examples

To build your own example:

```bash
gcc -Wall -O2 -o my_example my_example.c matrix_tree.o -lm
./my_example
```

## Helper Functions

You'll likely want these helper functions in your code:

```c
// Print a matrix tree (recursive)
void matrix_tree_print(MatrixTreeNode* node, int depth) {
    if (!node) {
        printf("NULL\n");
        return;
    }
    
    for (int i = 0; i < depth; i++) printf("  ");
    
    if (node->node_type == NODE_TYPE_LEAF) {
        printf("LEAF (%dx%d)\n", node->rows, node->cols);
        // Print matrix data...
    } else {
        printf("INTERNAL (%dx%d) with %lu children\n",
               node->rows, node->cols, node->num_children);
        MatrixTreeNode** children = (MatrixTreeNode**)node->data_ptr;
        for (uint64_t i = 0; i < node->num_children; i++) {
            matrix_tree_print(children[i], depth + 1);
        }
    }
}

// Create leaf with data in one call
MatrixTreeNode* create_leaf_with_data(
    uint32_t rows, uint32_t cols, const double* data
) {
    MatrixTreeNode* node = matrix_tree_create(rows, cols, NODE_TYPE_LEAF);
    if (!node) return NULL;
    
    size_t size = rows * cols * sizeof(double);
    if (matrix_tree_set_leaf(node, data, size) != 0) {
        matrix_tree_destroy(node);
        return NULL;
    }
    
    return node;
}

// Print raw matrix data
void print_matrix(const double* m, uint32_t rows, uint32_t cols) {
    printf("[\n");
    for (uint32_t i = 0; i < rows; i++) {
        printf("  ");
        for (uint32_t j = 0; j < cols; j++) {
            printf("%7.2f ", m[i * cols + j]);
        }
        printf("\n");
    }
    printf("]\n");
}
```

## Common Patterns

### Pattern 1: Weighted Sum of Matrices

```c
// Compute w1*A + w2*B + w3*C
MatrixTreeNode* A = create_leaf_with_data(n, n, a_data);
MatrixTreeNode* B = create_leaf_with_data(n, n, b_data);
MatrixTreeNode* C = create_leaf_with_data(n, n, c_data);

matrix_tree_scale(A, w1);
matrix_tree_scale(B, w2);
matrix_tree_scale(C, w3);

MatrixTreeNode* sum = matrix_tree_create(n, n, NODE_TYPE_INTERNAL);
MatrixTreeNode* children[] = {A, B, C};
matrix_tree_set_internal(sum, children, 3);

double result[n*n];
matrix_tree_collapse(sum, result);
```

### Pattern 2: Ensemble of Models

```c
// Store multiple model matrices, evaluate all
MatrixTreeNode* models[num_models];
for (int i = 0; i < num_models; i++) {
    models[i] = create_leaf_with_data(m, n, model_data[i]);
}

MatrixTreeNode* ensemble = matrix_tree_create(m, n, NODE_TYPE_INTERNAL);
matrix_tree_set_internal(ensemble, models, num_models);

// Get ensemble prediction (average)
double ensemble_result[m*n];
matrix_tree_collapse(ensemble, ensemble_result);

// Divide by num_models for true average
for (int i = 0; i < m*n; i++) {
    ensemble_result[i] /= num_models;
}
```

### Pattern 3: Hierarchical Aggregation

```c
// Build tree bottom-up for efficient aggregation
// Level 1: Individual matrices
// Level 2: Group sums
// Level 3: Total sum

// Useful for distributed/parallel scenarios
```

## Performance Tips

1. **Pre-allocate output buffers** - Avoid repeated allocation
2. **Reuse nodes** - Create once, use many times
3. **Minimize tree depth** - Flatter trees collapse faster  
4. **Batch operations** - Group multiple matrix operations
5. **Profile first** - Identify hotspots before optimizing

## Debugging Tips

1. **Check return values** - Functions return 0 on success, -1 on error
2. **Validate dimensions** - Ensure rows/cols match for operations
3. **Use print functions** - Visualize tree structure
4. **Memory leaks** - Always call `matrix_tree_destroy`
5. **Stack traces** - Build with `-g` flag for debugging

## Next Steps

- Extend with custom merge operations (min, max, etc.)
- Implement parallel collapse for large trees
- Add batch matrix-vector multiplication
- Optimize with SIMD intrinsics
- Port to GPU (CUDA/ROCm)

See `README.md` for architecture details and `demo.c` for working examples.
