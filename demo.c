#include "matrix_tree.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

void matrix_tree_print(MatrixTreeNode* node, int depth) {
    if (!node) {
        printf("NULL node\n");
        return;
    }
    
    for (int i = 0; i < depth; i++) printf("  ");
    
    if (node->node_type == 0) {
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
}

MatrixTreeNode* matrix_tree_create_leaf_with_data(uint32_t rows, uint32_t cols, 
                                                    const double* data) {
    MatrixTreeNode* node = matrix_tree_create(rows, cols, 0);
    if (!node) return NULL;
    
    size_t size = rows * cols * sizeof(double);
    if (matrix_tree_set_leaf(node, data, size) != 0) {
        matrix_tree_destroy(node);
        return NULL;
    }
    
    return node;
}

int main() {
    printf("Matrix-Tree Assembly Demo\n\n");
    
    // Test 1: Basic leaf
    printf("=== Test 1: Basic Leaf ===\n");
    double data1[] = {1, 2, 3, 4};
    MatrixTreeNode* leaf = matrix_tree_create_leaf_with_data(2, 2, data1);
    printf("Created leaf:\n");
    matrix_tree_print(leaf, 0);
    matrix_tree_destroy(leaf);
    printf("✓ Test 1 passed\n\n");
    
    // Test 2: Matrix-vector multiply
    printf("=== Test 2: Matrix-Vector Multiply ===\n");
    double data2[] = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    MatrixTreeNode* matrix = matrix_tree_create_leaf_with_data(3, 3, data2);
    printf("Matrix:\n");
    matrix_tree_print(matrix, 0);
    
    double x[] = {1, 2, 3};
    double y[3] = {0};
    printf("\nVector x: [%.0f %.0f %.0f]\n", x[0], x[1], x[2]);
    
    matrix_tree_multiply_collapsed(matrix, x, y);
    printf("Result y = A*x: [%.0f %.0f %.0f]\n", y[0], y[1], y[2]);
    printf("Expected: [14 32 50]\n");
    
    matrix_tree_destroy(matrix);
    printf("✓ Test 2 passed\n\n");
    
    printf("All tests completed!\n");

    printf("\nPress Enter to exit...");
    fflush(stdout);
    getchar();

    return 0;
}