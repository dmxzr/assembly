bits 64

section .data
    rows:    db 4
    columns: db 4

    matrix:
        dw  5, -3,  2, 7
        dw -2,  4, -1, 3
        dw  6,  1, -3, 2
        dw 10, 12,  0, 5

    %ifndef ASCENDING
        %define ASCENDING 1
    %endif
    ascending: db ASCENDING

section .bss
    sums:      resd 255
    new_order: resd 255
    temp_col:  resw 255
    visited:   resb 255

section .text
global _start

_start:
    movzx r8, byte [rows]
    movzx r9, byte [columns]

    cmp r9, 1
    jle .done

    xor rcx, rcx

.calc_sums:
    xor r10, r10
    xor r11, r11

.sum_loop:
    mov  rax, r10
    imul rax, r9
    add  rax, rcx
    shl  rax, 1
    movsx rbx, word [matrix + rax]
    add  r11d, ebx
    inc  r10
    cmp  r10, r8
    jl   .sum_loop

    mov  [sums + rcx*4], r11d
    inc  rcx
    cmp  rcx, r9
    jl   .calc_sums

    xor rcx, rcx

.init:
    mov  [new_order + rcx*4], ecx
    inc  rcx
    cmp  rcx, r9
    jl   .init

    movzx r12d, byte [ascending]
    mov   rcx, 1

.insertion_sort:
    mov  ebx, [new_order + rcx*4]
    mov  r11d, [sums + rbx*4]
    xor  rdx, rdx
    mov  rsi, rcx

.binary_search:
    cmp  rdx, rsi
    jge  .ins_place

    lea  rax, [rdx + rsi]
    shr  rax, 1

    mov  edi, [new_order + rax*4]
    mov  r15d, [sums + rdi*4]

    cmp  r12d, 1
    je   .asc_cmp

    cmp  r11d, r15d
    jg   .move_left
    lea  rdx, [rax + 1]
    jmp  .binary_search

.asc_cmp:
    cmp  r11d, r15d
    jl   .move_left
    lea  rdx, [rax + 1]
    jmp  .binary_search

.move_left:
    mov  rsi, rax
    jmp  .binary_search

.ins_place:
    mov rsi, rcx

.shift:
    cmp  rsi, rdx
    jle  .shift_done
    lea  rax, [rsi - 1]
    mov  edi, [new_order + rax*4]
    mov  [new_order + rsi*4], edi
    dec  rsi
    jmp  .shift

.shift_done:
    mov  [new_order + rdx*4], ebx
    inc  rcx
    cmp  rcx, r9
    jl   .insertion_sort

    xor rcx, rcx

.clear_vis:
    mov  byte [visited + rcx], 0
    inc  rcx
    cmp  rcx, r9
    jl   .clear_vis

    xor rcx, rcx

.perm_loop:
    cmp  rcx, r9
    jge  .done

    cmp  byte [visited + rcx], 1
    je   .perm_next

    mov  eax, [new_order + rcx*4]
    cmp  rax, rcx
    je   .perm_fixed

    xor r10, r10

.save_col:
    mov  rax, r10
    imul rax, r9
    add  rax, rcx
    shl  rax, 1
    mov  bx, [matrix + rax]
    mov  [temp_col + r10*2], bx
    inc  r10
    cmp  r10, r8
    jl   .save_col

    mov r13, rcx

.follow_cycle:
    mov  eax, [new_order + r13*4]
    mov  r14, rax
    cmp  r14, rcx
    je   .close_cycle

    xor r10, r10

.copy_col:
    mov  rax, r10
    imul rax, r9
    lea  rsi, [rax + r14]
    shl  rsi, 1
    mov  bx, [matrix + rsi]
    lea  rdi, [rax + r13]
    shl  rdi, 1
    mov  [matrix + rdi], bx
    inc  r10
    cmp  r10, r8
    jl   .copy_col

    mov  byte [visited + r13], 1
    mov  r13, r14
    jmp  .follow_cycle

.close_cycle:
    xor r10, r10

.restore_col:
    mov  bx, [temp_col + r10*2]
    mov  rax, r10
    imul rax, r9
    lea  rdi, [rax + r13]
    shl  rdi, 1
    mov  [matrix + rdi], bx
    inc  r10
    cmp  r10, r8
    jl   .restore_col

    mov  byte [visited + r13], 1
    jmp  .perm_next

.perm_fixed:
    mov  byte [visited + rcx], 1

.perm_next:
    inc  rcx
    jmp  .perm_loop

.done:
    xor  edi, edi
    mov  eax, 60
    syscall
