; Matrix-Tree Assembly Implementation
; x64 MASM syntax for Visual Studio
; Implements hierarchical matrix structures with tree-based storage
; Microsoft x64 calling convention

OPTION CASEMAP:NONE

.data
    ALIGN 8
    ; Error messages
    err_null_ptr    BYTE "Error: NULL pointer", 0Ah, 0
    err_bad_alloc   BYTE "Error: Allocation failed", 0Ah, 0
    err_bad_dim     BYTE "Error: Invalid dimensions", 0Ah, 0

.data?
    ALIGN 8
    temp_buffer     BYTE 8192 DUP(?)    ; Temporary computation buffer

.code

; External C runtime functions
EXTERN malloc:PROC
EXTERN free:PROC
EXTERN memset:PROC
EXTERN memcpy:PROC

; Public functions
PUBLIC matrix_tree_create
PUBLIC matrix_tree_destroy
PUBLIC matrix_tree_set_leaf
PUBLIC matrix_tree_set_internal
PUBLIC matrix_tree_collapse
PUBLIC matrix_tree_multiply_collapsed
PUBLIC matrix_tree_scale

; Data Structure Layout (in memory):
; TreeNode structure (32 bytes):
;   +0:  node_type (8 bytes) - 0=leaf, 1=internal
;   +8:  rows (4 bytes)
;   +12: cols (4 bytes)
;   +16: data_ptr (8 bytes) - points to matrix data if leaf, or children array if internal
;   +24: num_children (8 bytes) - only used for internal nodes

; Function: matrix_tree_create
; Creates a new matrix tree node
; Args: rcx = rows, rdx = cols, r8 = node_type (0=leaf, 1=internal)
; Returns: rax = pointer to new node, or NULL on failure
matrix_tree_create PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 60h                ; Shadow space + alignment + locals
    .allocstack 60h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    .endprolog

    ; Save parameters
    mov r12, rcx                ; rows
    mov r13, rdx                ; cols
    mov r14, r8                 ; node_type

    ; Validate dimensions
    test r12, r12
    jz create_error
    test r13, r13
    jz create_error

    ; Allocate TreeNode structure (32 bytes)
    mov rcx, 32
    call malloc
    test rax, rax
    jz create_error

    mov rbx, rax                ; Save node pointer

    ; Initialize node fields
    mov QWORD PTR [rbx], r14    ; node_type
    mov DWORD PTR [rbx+8], r12d ; rows
    mov DWORD PTR [rbx+12], r13d ; cols
    mov QWORD PTR [rbx+16], 0   ; data_ptr (NULL initially)
    mov QWORD PTR [rbx+24], 0   ; num_children

    ; If leaf node, allocate matrix data
    cmp r14, 0
    jne create_done

    ; Allocate rows * cols * 8 bytes for doubles
    mov rax, r12
    imul rax, r13
    shl rax, 3                  ; multiply by 8
    mov rcx, rax
    call malloc
    test rax, rax
    jz create_cleanup

    mov QWORD PTR [rbx+16], rax ; Store data pointer

    ; Zero initialize matrix data
    mov rcx, QWORD PTR [rbx+16]
    xor edx, edx                ; fill with 0
    mov rax, r12
    imul rax, r13
    shl rax, 3
    mov r8, rax                 ; size
    call memset

create_done:
    mov rax, rbx
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret

create_cleanup:
    mov rcx, rbx
    call free
create_error:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret
matrix_tree_create ENDP

; Function: matrix_tree_destroy
; Recursively destroys a matrix tree node and all children
; Args: rcx = pointer to node
; Returns: void
matrix_tree_destroy PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 60h
    .allocstack 60h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    .endprolog

    ; Check for NULL
    test rcx, rcx
    jz destroy_done

    mov rbx, rcx                ; Save node pointer

    ; Get node type
    mov rax, QWORD PTR [rbx]

    ; If internal node, destroy children first
    cmp rax, 1
    jne destroy_leaf

    ; Internal node - destroy all children
    mov r12, QWORD PTR [rbx+16] ; children array
    mov r13, QWORD PTR [rbx+24] ; num_children

    test r12, r12
    jz destroy_node

    xor r14, r14                ; counter
destroy_loop:
    cmp r14, r13
    jge destroy_children_done

    ; Destroy child at index r14
    mov rcx, QWORD PTR [r12+r14*8]
    call matrix_tree_destroy

    inc r14
    jmp destroy_loop

destroy_children_done:
    ; Free children array
    mov rcx, r12
    call free
    jmp destroy_node

destroy_leaf:
    ; Leaf node - free matrix data
    mov rcx, QWORD PTR [rbx+16]
    test rcx, rcx
    jz destroy_node
    call free

destroy_node:
    ; Free the node itself
    mov rcx, rbx
    call free

destroy_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret
matrix_tree_destroy ENDP

; Function: matrix_tree_set_leaf
; Sets the matrix data for a leaf node
; Args: rcx = node pointer, rdx = data pointer, r8 = data_size
; Returns: rax = 0 on success, -1 on error
matrix_tree_set_leaf PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 40h
    .allocstack 40h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    .endprolog

    mov rbx, rcx                ; Save node pointer
    mov r12, rdx                ; Save data pointer

    ; Validate node is leaf type
    mov rax, QWORD PTR [rbx]
    test rax, rax
    jnz setleaf_error

    ; Get dimensions
    mov eax, DWORD PTR [rbx+8]  ; rows
    mov ecx, DWORD PTR [rbx+12] ; cols
    imul rax, rcx
    shl rax, 3                  ; * 8 bytes

    ; Validate size
    cmp rax, r8
    jne setleaf_error

    ; Copy data
    mov rcx, QWORD PTR [rbx+16] ; destination
    mov rdx, r12                ; source
    mov r8, rax                 ; size
    call memcpy

    xor eax, eax
    pop r12
    pop rbx
    add rsp, 40h
    pop rbp
    ret

setleaf_error:
    mov rax, -1
    pop r12
    pop rbx
    add rsp, 40h
    pop rbp
    ret
matrix_tree_set_leaf ENDP

; Function: matrix_tree_set_internal
; Sets children for an internal node
; Args: rcx = node pointer, rdx = children array, r8 = num_children
; Returns: rax = 0 on success, -1 on error
matrix_tree_set_internal PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 40h
    .allocstack 40h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    .endprolog

    mov rbx, rcx                ; node pointer
    mov r12, rdx                ; children array
    mov r13, r8                 ; num_children

    ; Validate node is internal type
    mov rax, QWORD PTR [rbx]
    cmp rax, 1
    jne setinternal_error

    ; Allocate array for child pointers
    mov rax, r13
    shl rax, 3                  ; * 8 bytes per pointer
    mov rcx, rax
    call malloc
    test rax, rax
    jz setinternal_error

    ; Store in node
    mov QWORD PTR [rbx+16], rax
    mov QWORD PTR [rbx+24], r13

    ; Copy child pointers
    mov rcx, rax                ; destination
    mov rdx, r12                ; source
    mov rax, r13
    shl rax, 3
    mov r8, rax                 ; size
    call memcpy

    xor eax, eax
    pop r13
    pop r12
    pop rbx
    add rsp, 40h
    pop rbp
    ret

setinternal_error:
    mov rax, -1
    pop r13
    pop r12
    pop rbx
    add rsp, 40h
    pop rbp
    ret
matrix_tree_set_internal ENDP

; Function: matrix_tree_collapse
; Collapses a tree into a single matrix by summing all leaf nodes
; Args: rcx = node pointer, rdx = output buffer (pre-allocated)
; Returns: rax = 0 on success, -1 on error
matrix_tree_collapse PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 60h
    .allocstack 60h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    push r15
    .pushreg r15
    .endprolog

    mov rbx, rcx                ; node
    mov r12, rdx                ; output buffer

    ; Check node type
    mov rax, QWORD PTR [rbx]
    test rax, rax
    jz collapse_leaf

    ; Internal node - recursively collapse children and sum
    mov r13, QWORD PTR [rbx+16] ; children array
    mov r14, QWORD PTR [rbx+24] ; num_children

    ; Get matrix dimensions
    mov eax, DWORD PTR [rbx+8]  ; rows
    mov ecx, DWORD PTR [rbx+12] ; cols
    imul rax, rcx
    mov r15, rax                ; total elements

    ; Zero output buffer
    mov rcx, r12
    xor edx, edx
    mov r8, r15
    shl r8, 3
    call memset

    ; Sum all children
    xor rax, rax                ; child index

collapse_sum_loop:
    cmp rax, r14
    jge collapse_done

    ; Save counter
    mov QWORD PTR [rbp-8], rax

    ; Collapse child into temp buffer
    mov rcx, QWORD PTR [r13+rax*8]
    lea rdx, temp_buffer
    call matrix_tree_collapse

    ; Restore counter
    mov rax, QWORD PTR [rbp-8]

    ; Add temp buffer to output
    xor rdx, rdx                ; element counter
collapse_add_loop:
    cmp rdx, r15
    jge collapse_next_child

    ; Load and add doubles
    movsd xmm0, QWORD PTR [r12+rdx*8]
    lea rcx, temp_buffer
    movsd xmm1, QWORD PTR [rcx+rdx*8]
    addsd xmm0, xmm1
    movsd QWORD PTR [r12+rdx*8], xmm0

    inc rdx
    jmp collapse_add_loop

collapse_next_child:
    mov rax, QWORD PTR [rbp-8]
    inc rax
    jmp collapse_sum_loop

collapse_leaf:
    ; Leaf node - copy data to output
    mov eax, DWORD PTR [rbx+8]  ; rows
    mov ecx, DWORD PTR [rbx+12] ; cols
    imul rax, rcx
    shl rax, 3

    mov rcx, r12                ; dest
    mov rdx, QWORD PTR [rbx+16] ; source
    mov r8, rax                 ; size
    call memcpy

collapse_done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret
matrix_tree_collapse ENDP

; Function: matrix_tree_multiply_collapsed
; Multiplies collapsed matrix by vector: y = A*x
; Args: rcx = node, rdx = input vector x, r8 = output vector y
; Returns: rax = 0 on success
matrix_tree_multiply_collapsed PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 60h
    .allocstack 60h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    push r15
    .pushreg r15
    .endprolog

    mov rbx, rcx                ; node
    mov r12, rdx                ; x vector
    mov r13, r8                 ; y vector

    ; Collapse tree to temp buffer
    mov rcx, rbx
    lea rdx, temp_buffer
    call matrix_tree_collapse

    ; Get dimensions
    mov eax, DWORD PTR [rbx+8]  ; rows
    mov ecx, DWORD PTR [rbx+12] ; cols
    mov r14d, eax               ; rows
    mov r15d, ecx               ; cols

    ; Perform matrix-vector multiplication
    xor r8, r8                  ; row counter
mvcollapse_row_loop:
    cmp r8d, r14d
    jge mvcollapse_done

    ; Compute dot product for this row
    xorpd xmm0, xmm0            ; accumulator
    xor r9, r9                  ; col counter

mvcollapse_col_loop:
    cmp r9d, r15d
    jge mvcollapse_store

    ; Compute offset: row * cols + col
    mov rax, r8
    imul rax, r15
    add rax, r9

    ; Load matrix element and vector element
    lea r10, temp_buffer
    movsd xmm1, QWORD PTR [r10+rax*8]
    movsd xmm2, QWORD PTR [r12+r9*8]

    ; Multiply and accumulate
    mulsd xmm1, xmm2
    addsd xmm0, xmm1

    inc r9
    jmp mvcollapse_col_loop

mvcollapse_store:
    ; Store result
    movsd QWORD PTR [r13+r8*8], xmm0
    inc r8
    jmp mvcollapse_row_loop

mvcollapse_done:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret
matrix_tree_multiply_collapsed ENDP

; Function: matrix_tree_scale
; Scales a matrix tree by a scalar: A' = s * A
; Args: rcx = node, xmm0 = scalar
; Returns: void
matrix_tree_scale PROC FRAME
    push rbp
    .pushreg rbp
    mov rbp, rsp
    .setframe rbp, 0
    sub rsp, 60h                ; Shadow space + local storage + alignment
    .allocstack 60h
    push rbx
    .pushreg rbx
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    .endprolog

    mov rbx, rcx
    movsd QWORD PTR [rbp-8], xmm0 ; Save scalar on stack

    ; Check node type
    mov rax, QWORD PTR [rbx]
    test rax, rax
    jz scale_leaf

    ; Internal node - scale all children
    mov r12, QWORD PTR [rbx+16] ; children
    mov r13, QWORD PTR [rbx+24] ; num_children

    xor r14, r14
scale_children_loop:
    cmp r14, r13
    jge scale_done

    mov rcx, QWORD PTR [r12+r14*8]
    movsd xmm0, QWORD PTR [rbp-8]
    call matrix_tree_scale

    inc r14
    jmp scale_children_loop

scale_leaf:
    ; Scale leaf matrix data
    mov eax, DWORD PTR [rbx+8]  ; rows
    mov ecx, DWORD PTR [rbx+12] ; cols
    imul rax, rcx
    mov r12, rax                ; num elements

    mov r13, QWORD PTR [rbx+16] ; data
    xor r14, r14
    movsd xmm15, QWORD PTR [rbp-8] ; Load scalar

scale_loop:
    cmp r14, r12
    jge scale_done

    movsd xmm0, QWORD PTR [r13+r14*8]
    mulsd xmm0, xmm15
    movsd QWORD PTR [r13+r14*8], xmm0

    inc r14
    jmp scale_loop

scale_done:
    pop r14
    pop r13
    pop r12
    pop rbx
    add rsp, 60h
    pop rbp
    ret
matrix_tree_scale ENDP

END