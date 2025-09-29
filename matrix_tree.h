#ifndef MATRIX_TREE_H
#define MATRIX_TREE_H

#include <stdint.h>
#include <stddef.h>

// Node types
#define NODE_TYPE_LEAF     0
#define NODE_TYPE_INTERNAL 1

// Tree node structure (must match assembly layout)
typedef struct MatrixTreeNode {
    uint64_t node_type;      // 0 = leaf, 1 = internal
    uint32_t rows;
    uint32_t cols;
    void* data_ptr;          // Matrix data or children array
    uint64_t num_children;
} MatrixTreeNode;

// Function prototypes (implemented in assembly)
extern MatrixTreeNode* matrix_tree_create(uint32_t rows, uint32_t cols, uint64_t node_type);
extern void matrix_tree_destroy(MatrixTreeNode* node);
extern int matrix_tree_set_leaf(MatrixTreeNode* node, const double* data, size_t data_size);
extern int matrix_tree_set_internal(MatrixTreeNode* node, MatrixTreeNode** children, uint64_t num_children);
extern int matrix_tree_collapse(MatrixTreeNode* node, double* output);
extern int matrix_tree_multiply_collapsed(MatrixTreeNode* node, const double* x, double* y);
extern void matrix_tree_scale(MatrixTreeNode* node, double scalar);

// Helper function prototypes (C implementations)
void matrix_tree_print(MatrixTreeNode* node, int depth);
MatrixTreeNode* matrix_tree_create_leaf_with_data(uint32_t rows, uint32_t cols, const double* data);
void matrix_tree_print_matrix(const double* matrix, uint32_t rows, uint32_t cols);

#endif // MATRIX_TREE_H
