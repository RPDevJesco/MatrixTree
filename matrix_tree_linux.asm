# Matrix-Tree Assembly Implementation
# x86-64 AT&T syntax
# Implements hierarchical matrix structures with tree-based storage

.section .data
    .align 8
    # Error messages
err_null_ptr:    .asciz "Error: NULL pointer\n"
err_bad_alloc:   .asciz "Error: Allocation failed\n"
err_bad_dim:     .asciz "Error: Invalid dimensions\n"

.section .bss
    .align 8
    .lcomm temp_buffer, 8192    # Temporary computation buffer

.section .text
    .global matrix_tree_create
    .global matrix_tree_destroy
    .global matrix_tree_set_leaf
    .global matrix_tree_set_internal
    .global matrix_tree_collapse
    .global matrix_tree_multiply_collapsed
    .global matrix_tree_scale

# Data Structure Layout (in memory):
# TreeNode structure (32 bytes):
#   +0:  node_type (8 bytes) - 0=leaf, 1=internal
#   +8:  rows (4 bytes)
#   +12: cols (4 bytes)
#   +16: data_ptr (8 bytes) - points to matrix data if leaf, or children array if internal
#   +24: num_children (8 bytes) - only used for internal nodes

# Function: matrix_tree_create
# Creates a new matrix tree node
# Args: %rdi = rows, %rsi = cols, %rdx = node_type (0=leaf, 1=internal)
# Returns: %rax = pointer to new node, or NULL on failure
matrix_tree_create:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    
    # Save parameters
    movq %rdi, %r12             # rows
    movq %rsi, %r13             # cols
    movq %rdx, %r14             # node_type
    
    # Validate dimensions
    testq %r12, %r12
    jz .create_error
    testq %r13, %r13
    jz .create_error
    
    # Allocate TreeNode structure (32 bytes)
    movq $32, %rdi
    call malloc@PLT
    testq %rax, %rax
    jz .create_error
    
    movq %rax, %rbx             # Save node pointer
    
    # Initialize node fields
    movq %r14, (%rbx)           # node_type
    movl %r12d, 8(%rbx)         # rows
    movl %r13d, 12(%rbx)        # cols
    movq $0, 16(%rbx)           # data_ptr (NULL initially)
    movq $0, 24(%rbx)           # num_children
    
    # If leaf node, allocate matrix data
    cmpq $0, %r14
    jne .create_done
    
    # Allocate rows * cols * 8 bytes for doubles
    movq %r12, %rax
    imulq %r13, %rax
    shlq $3, %rax               # multiply by 8
    movq %rax, %rdi
    call malloc@PLT
    testq %rax, %rax
    jz .create_cleanup
    
    movq %rax, 16(%rbx)         # Store data pointer
    
    # Zero initialize matrix data
    movq 16(%rbx), %rdi
    movq %r12, %rax
    imulq %r13, %rax
    shlq $3, %rax
    movq $0, %rsi
    movq %rax, %rdx
    call memset@PLT
    
.create_done:
    movq %rbx, %rax
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

.create_cleanup:
    movq %rbx, %rdi
    call free@PLT
.create_error:
    xorq %rax, %rax
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_destroy
# Recursively destroys a matrix tree node and all children
# Args: %rdi = pointer to node
# Returns: void
matrix_tree_destroy:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    
    # Check for NULL
    testq %rdi, %rdi
    jz .destroy_done
    
    movq %rdi, %rbx             # Save node pointer
    
    # Get node type
    movq (%rbx), %rax
    
    # If internal node, destroy children first
    cmpq $1, %rax
    jne .destroy_leaf
    
    # Internal node - destroy all children
    movq 16(%rbx), %r12         # children array
    movq 24(%rbx), %r13         # num_children
    
    testq %r12, %r12
    jz .destroy_node
    
    xorq %rcx, %rcx             # counter
.destroy_loop:
    cmpq %r13, %rcx
    jge .destroy_children_done
    
    # Destroy child at index rcx
    movq (%r12, %rcx, 8), %rdi
    pushq %rcx
    call matrix_tree_destroy
    popq %rcx
    
    incq %rcx
    jmp .destroy_loop
    
.destroy_children_done:
    # Free children array
    movq %r12, %rdi
    call free@PLT
    jmp .destroy_node
    
.destroy_leaf:
    # Leaf node - free matrix data
    movq 16(%rbx), %rdi
    testq %rdi, %rdi
    jz .destroy_node
    call free@PLT
    
.destroy_node:
    # Free the node itself
    movq %rbx, %rdi
    call free@PLT
    
.destroy_done:
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_set_leaf
# Sets the matrix data for a leaf node
# Args: %rdi = node pointer, %rsi = data pointer, %rdx = data_size
# Returns: %rax = 0 on success, -1 on error
matrix_tree_set_leaf:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    
    # Validate node is leaf type
    movq (%rdi), %rax
    testq %rax, %rax
    jnz .setleaf_error
    
    # Get dimensions
    movl 8(%rdi), %eax          # rows
    movl 12(%rdi), %ecx         # cols
    imulq %rcx, %rax
    shlq $3, %rax               # * 8 bytes
    
    # Validate size
    cmpq %rdx, %rax
    jne .setleaf_error
    
    # Copy data
    movq %rdi, %rbx
    movq 16(%rbx), %rdi         # destination
    # %rsi already has source
    movq %rax, %rdx             # size
    call memcpy@PLT
    
    xorq %rax, %rax
    popq %rbx
    popq %rbp
    ret
    
.setleaf_error:
    movq $-1, %rax
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_set_internal
# Sets children for an internal node
# Args: %rdi = node pointer, %rsi = children array, %rdx = num_children
# Returns: %rax = 0 on success, -1 on error
matrix_tree_set_internal:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    
    # Validate node is internal type
    movq (%rdi), %rax
    cmpq $1, %rax
    jne .setinternal_error
    
    movq %rdi, %rbx
    movq %rdx, %r12
    
    # Allocate array for child pointers
    movq %r12, %rdi
    shlq $3, %rdi               # * 8 bytes per pointer
    call malloc@PLT
    testq %rax, %rax
    jz .setinternal_error
    
    # Store in node
    movq %rax, 16(%rbx)
    movq %r12, 24(%rbx)
    
    # Copy child pointers
    movq %rax, %rdi
    # %rsi already has source
    movq %r12, %rdx
    shlq $3, %rdx
    call memcpy@PLT
    
    xorq %rax, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret
    
.setinternal_error:
    movq $-1, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_collapse
# Collapses a tree into a single matrix by summing all leaf nodes
# Args: %rdi = node pointer, %rsi = output buffer (pre-allocated)
# Returns: %rax = 0 on success, -1 on error
matrix_tree_collapse:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    
    movq %rdi, %rbx             # node
    movq %rsi, %r12             # output buffer
    
    # Check node type
    movq (%rbx), %rax
    testq %rax, %rax
    jz .collapse_leaf
    
    # Internal node - recursively collapse children and sum
    movq 16(%rbx), %r13         # children array
    movq 24(%rbx), %r14         # num_children
    
    # Get matrix dimensions
    movl 8(%rbx), %eax          # rows
    movl 12(%rbx), %ecx         # cols
    imulq %rcx, %rax
    movq %rax, %r15             # total elements
    
    # Zero output buffer
    movq %r12, %rdi
    xorq %rsi, %rsi
    movq %r15, %rdx
    shlq $3, %rdx
    call memset@PLT
    
    # Sum all children
    xorq %rcx, %rcx             # child counter
.collapse_sum_loop:
    cmpq %r14, %rcx
    jge .collapse_done
    
    # Collapse child into temp buffer
    movq (%r13, %rcx, 8), %rdi
    leaq temp_buffer(%rip), %rsi
    pushq %rcx
    call matrix_tree_collapse
    popq %rcx
    
    # Add temp buffer to output
    xorq %rdx, %rdx             # element counter
.collapse_add_loop:
    cmpq %r15, %rdx
    jge .collapse_next_child
    
    # Load and add doubles
    movsd (%r12, %rdx, 8), %xmm0
    leaq temp_buffer(%rip), %rax
    movsd (%rax, %rdx, 8), %xmm1
    addsd %xmm1, %xmm0
    movsd %xmm0, (%r12, %rdx, 8)
    
    incq %rdx
    jmp .collapse_add_loop
    
.collapse_next_child:
    incq %rcx
    jmp .collapse_sum_loop
    
.collapse_leaf:
    # Leaf node - copy data to output
    movl 8(%rbx), %eax          # rows
    movl 12(%rbx), %ecx         # cols
    imulq %rcx, %rax
    shlq $3, %rax
    
    movq %r12, %rdi
    movq 16(%rbx), %rsi
    movq %rax, %rdx
    call memcpy@PLT
    
.collapse_done:
    xorq %rax, %rax
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_multiply_collapsed
# Multiplies collapsed matrix by vector: y = A*x
# Args: %rdi = node, %rsi = input vector x, %rdx = output vector y
# Returns: %rax = 0 on success
matrix_tree_multiply_collapsed:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    
    movq %rdi, %rbx             # node
    movq %rsi, %r12             # x vector
    movq %rdx, %r13             # y vector
    
    # Collapse tree to temp buffer
    movq %rbx, %rdi
    leaq temp_buffer(%rip), %rsi
    call matrix_tree_collapse
    
    # Get dimensions
    movl 8(%rbx), %eax          # rows
    movl 12(%rbx), %ecx         # cols
    movl %eax, %r14d            # rows
    
    # Perform matrix-vector multiplication
    xorq %r8, %r8               # row counter
.mvcollapse_row_loop:
    cmpl %r14d, %r8d
    jge .mvcollapse_done
    
    # Compute dot product for this row
    xorpd %xmm0, %xmm0          # accumulator
    xorq %r9, %r9               # col counter
    
.mvcollapse_col_loop:
    cmpl %ecx, %r9d
    jge .mvcollapse_store
    
    # Compute offset: row * cols + col
    movq %r8, %rax
    imulq %rcx, %rax
    addq %r9, %rax
    
    # Load matrix element and vector element
    leaq temp_buffer(%rip), %r10
    movsd (%r10, %rax, 8), %xmm1
    movsd (%r12, %r9, 8), %xmm2
    
    # Multiply and accumulate
    mulsd %xmm2, %xmm1
    addsd %xmm1, %xmm0
    
    incq %r9
    jmp .mvcollapse_col_loop
    
.mvcollapse_store:
    # Store result
    movsd %xmm0, (%r13, %r8, 8)
    incq %r8
    jmp .mvcollapse_row_loop
    
.mvcollapse_done:
    xorq %rax, %rax
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# Function: matrix_tree_scale
# Scales a matrix tree by a scalar: A' = s * A
# Args: %rdi = node, %xmm0 = scalar
# Returns: void
matrix_tree_scale:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $16, %rsp              # Allocate space for scalar (16-byte aligned)
    
    movq %rdi, %rbx
    movsd %xmm0, -8(%rbp)       # Save scalar on stack
    
    # Check node type
    movq (%rbx), %rax
    testq %rax, %rax
    jz .scale_leaf
    
    # Internal node - scale all children
    movq 16(%rbx), %r12         # children
    movq 24(%rbx), %r13         # num_children
    
    xorq %rcx, %rcx
.scale_children_loop:
    cmpq %r13, %rcx
    jge .scale_done
    
    movq (%r12, %rcx, 8), %rdi
    movsd -8(%rbp), %xmm0
    pushq %rcx
    call matrix_tree_scale
    popq %rcx
    
    incq %rcx
    jmp .scale_children_loop
    
.scale_leaf:
    # Scale leaf matrix data
    movl 8(%rbx), %eax          # rows
    movl 12(%rbx), %ecx         # cols
    imulq %rcx, %rax
    movq %rax, %r12             # num elements
    
    movq 16(%rbx), %r13         # data
    xorq %rcx, %rcx
    movsd -8(%rbp), %xmm15      # Load scalar
    
.scale_loop:
    cmpq %r12, %rcx
    jge .scale_done
    
    movsd (%r13, %rcx, 8), %xmm0
    mulsd %xmm15, %xmm0
    movsd %xmm0, (%r13, %rcx, 8)
    
    incq %rcx
    jmp .scale_loop
    
.scale_done:
    addq $16, %rsp              # Deallocate stack space
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
