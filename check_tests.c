#include "matrix_tree.h"
#include <stdio.h>

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
    printf("===  Matrix-Tree Assembly Implementation ===\n");
    
    double data[] = {1.0, 2.0, 3.0, 4.0};
    MatrixTreeNode* leaf = matrix_tree_create_leaf_with_data(2, 2, data);
    if (!leaf) {
        printf("Failed to create leaf\n");
        printf("\nPress Enter to exit...");
        fflush(stdout);
        getchar();
        return 1;
    }

    printf("Created leaf node:\n");
    matrix_tree_print(leaf, 0);

    matrix_tree_destroy(leaf);
    printf("Test passed!\n");

    printf("\nPress Enter to exit...");
    fflush(stdout);
    getchar();

    return 0;
}