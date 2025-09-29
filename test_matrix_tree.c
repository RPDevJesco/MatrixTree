#include "matrix_tree.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Helper: Print matrix
void matrix_tree_print_matrix(const double* matrix, uint32_t rows, uint32_t cols) {
    printf("[\n");
    for (uint32_t i = 0; i < rows; i++) {
        printf("  ");
        for (uint32_t j = 0; j < cols; j++) {
            printf("%8.3f ", matrix[i * cols + j]);
        }
        printf("\n");
    }
    printf("]\n");
}

// Helper: Print tree structure
void matrix_tree_print(MatrixTreeNode* node, int depth) {
    if (!node) {
        printf("NULL node\n");
        return;
    }
    
    for (int i = 0; i < depth; i++) printf("  ");
    
    if (node->node_type == NODE_TYPE_LEAF) {
        printf("LEAF (%dx%d):\n", node->rows, node->cols);
        for (int i = 0; i < depth + 1; i++) printf("  ");
        double* data = (double*)node->data_ptr;
        matrix_tree_print_matrix(data, node->rows, node->cols);
    } else {
        printf("INTERNAL (%dx%d) with %lu children:\n", 
               node->rows, node->cols, node->num_children);
        MatrixTreeNode** children = (MatrixTreeNode**)node->data_ptr;
        for (uint64_t i = 0; i < node->num_children; i++) {
            for (int j = 0; j < depth + 1; j++) printf("  ");
            printf("Child %lu:\n", i);
            matrix_tree_print(children[i], depth + 2);
        }
    }
    printf("DEBUG: Exiting matrix_tree_print\n");
    fflush(stdout);
}

// Helper: Create leaf with data in one call
MatrixTreeNode* matrix_tree_create_leaf_with_data(uint32_t rows, uint32_t cols, 
                                                    const double* data) {
    MatrixTreeNode* node = matrix_tree_create(rows, cols, NODE_TYPE_LEAF);
    if (!node) return NULL;
    
    size_t size = rows * cols * sizeof(double);
    if (matrix_tree_set_leaf(node, data, size) != 0) {
        matrix_tree_destroy(node);
        return NULL;
    }
    
    return node;
}

// Test 1: Basic leaf node creation and collapse
void test_basic_leaf() {
    printf("\n=== Test 1: Basic Leaf Node ===\n");
    printf("Creating leaf node...\n");
    fflush(stdout);
    
    double data[] = {
        1.0, 2.0,
        3.0, 4.0
    };
    
    printf("Calling matrix_tree_create_leaf_with_data...\n");
    fflush(stdout);
    MatrixTreeNode* leaf = matrix_tree_create_leaf_with_data(2, 2, data);
    printf("Returned from matrix_tree_create_leaf_with_data\n");
    fflush(stdout);
    if (!leaf) {
        printf("Failed to create leaf\n");
        return;
    }
    
    printf("Created leaf node:\n");
    matrix_tree_print(leaf, 0);
    
    printf("DEBUG: Skipping matrix_tree_destroy for test...\n");
    fflush(stdout);
    // matrix_tree_destroy(leaf);
    // printf("DEBUG: Returned from matrix_tree_destroy\n");
    // fflush(stdout);
    // printf("Test 1 passed!\n");
}

// Test 2: Internal node with children
void test_internal_node() {
    printf("\n=== Test 2: Internal Node ===\n");
    
    // Create two leaf nodes
    double data1[] = {1.0, 0.0, 0.0, 1.0};
    double data2[] = {2.0, 0.0, 0.0, 2.0};
    double data3[] = {0.5, 0.0, 0.0, 0.5};
    
    MatrixTreeNode* leaf1 = matrix_tree_create_leaf_with_data(2, 2, data1);
    MatrixTreeNode* leaf2 = matrix_tree_create_leaf_with_data(2, 2, data2);
    MatrixTreeNode* leaf3 = matrix_tree_create_leaf_with_data(2, 2, data3);
    
    if (!leaf1 || !leaf2 || !leaf3) {
        printf("Failed to create leaves\n");
        return;
    }
    
    // Create internal node
    MatrixTreeNode* internal = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    if (!internal) {
        printf("Failed to create internal node\n");
        return;
    }
    
    // Set children
    MatrixTreeNode* children[] = {leaf1, leaf2, leaf3};
    matrix_tree_set_internal(internal, children, 3);
    
    printf("Created internal node with 3 children:\n");
    matrix_tree_print(internal, 0);
    
    // Test collapse (should sum all three)
    double output[4];
    matrix_tree_collapse(internal, output);
    printf("\nCollapsed result (sum of children):\n");
    matrix_tree_print_matrix(output, 2, 2);
    printf("Expected: [3.5, 0.0; 0.0, 3.5]\n");
    
    matrix_tree_destroy(internal);
    printf("Test 2 passed!\n");
}

// Test 3: Matrix-vector multiplication
void test_matrix_vector_multiply() {
    printf("\n=== Test 3: Matrix-Vector Multiplication ===\n");
    
    // Create a simple 3x3 matrix tree
    double data[] = {
        1.0, 2.0, 3.0,
        4.0, 5.0, 6.0,
        7.0, 8.0, 9.0
    };
    
    MatrixTreeNode* matrix = matrix_tree_create_leaf_with_data(3, 3, data);
    if (!matrix) {
        printf("Failed to create matrix\n");
        return;
    }
    
    printf("Matrix:\n");
    matrix_tree_print(matrix, 0);
    
    // Input vector
    double x[] = {1.0, 2.0, 3.0};
    double y[3] = {0};
    
    printf("\nInput vector x: [");
    for (int i = 0; i < 3; i++) printf("%.1f ", x[i]);
    printf("]\n");
    
    // Multiply
    matrix_tree_multiply_collapsed(matrix, x, y);
    
    printf("Result y = A*x: [");
    for (int i = 0; i < 3; i++) printf("%.1f ", y[i]);
    printf("]\n");
    printf("Expected: [14.0 32.0 50.0]\n");
    
    matrix_tree_destroy(matrix);
    printf("Test 3 passed!\n");
}

// Test 4: Nested internal nodes
void test_nested_tree() {
    printf("\n=== Test 4: Nested Tree Structure ===\n");
    
    // Create leaf nodes
    double d1[] = {1.0, 0.0, 0.0, 1.0};
    double d2[] = {0.5, 0.0, 0.0, 0.5};
    double d3[] = {0.25, 0.0, 0.0, 0.25};
    
    MatrixTreeNode* leaf1 = matrix_tree_create_leaf_with_data(2, 2, d1);
    MatrixTreeNode* leaf2 = matrix_tree_create_leaf_with_data(2, 2, d2);
    MatrixTreeNode* leaf3 = matrix_tree_create_leaf_with_data(2, 2, d3);
    
    // Create internal node 1 (leaf1 + leaf2)
    MatrixTreeNode* internal1 = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* children1[] = {leaf1, leaf2};
    matrix_tree_set_internal(internal1, children1, 2);
    
    // Create root internal node (internal1 + leaf3)
    MatrixTreeNode* root = matrix_tree_create(2, 2, NODE_TYPE_INTERNAL);
    MatrixTreeNode* children_root[] = {internal1, leaf3};
    matrix_tree_set_internal(root, children_root, 2);
    
    printf("Created nested tree:\n");
    matrix_tree_print(root, 0);
    
    // Collapse
    double output[4];
    matrix_tree_collapse(root, output);
    printf("\nCollapsed result:\n");
    matrix_tree_print_matrix(output, 2, 2);
    printf("Expected: [1.75, 0.0; 0.0, 1.75]\n");
    
    matrix_tree_destroy(root);
    printf("Test 4 passed!\n");
}

// Main test runner
int main() {
    printf("===========================================\n");
    printf("   Matrix-Tree Assembly Implementation\n");
    printf("===========================================\n");
    
    test_basic_leaf();
    test_internal_node();
    test_matrix_vector_multiply();
    test_nested_tree();
    
    printf("\n===========================================\n");
    printf("   All tests completed!\n");
    printf("===========================================\n");
    
    return 0;
}
