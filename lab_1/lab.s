bits 64
;   result = (a * (b + c) - d * (e + a)) / (d^2 - c^2*b)

section .data
    result: dq 0
    a: dd 1000000000 ; 32 bit
    b: dw 0 ; 16 bit
    c: dd 1000000000 ; 32 bit
    d: dw 1 ; 16 bit
    e: dd 1000000000 ; 32 bit

section .text
global _start
_start:
    ; (a * (b + c) - d * (e + a))
    ; b + c
    xor rax, rax
    movzx eax, word[b]
    add eax, dword[c]
    jc err
    ; a * (b + c)
    xor rbx, rbx
    mov ebx, dword[a]
    mul ebx ; result in rax

    shl rdx, 32
    or rax, rdx

    xor rcx, rcx
    mov rcx, rax ; res in rcx
; work
    ; e + a
    xor rax, rax
    mov eax, dword[e]
    add eax, dword[a]
    jc err
    ; work
    ; d * (e + a)
    xor rbx, rbx
    movzx ebx, word[d]
    mul ebx ; res in rax

    shl rdx, 32
    or rax, rdx

    xor rdx, rdx
    mov rdx, rax ; res in rdx
; work
    ; a * (b + c) - d * (e + a)
    sub  rcx, rdx ; res in rcx
    xor r8, r8
    mov r8, rcx
    jc err


    ; d^2 - c^2 * b
    ; d^2
    xor rax, rax
    movzx eax, word[d]
    mul eax

    shl rdx, 32
    or rax, rdx

    mov rcx, rax
    ;work
    ; c^2
    xor rax, rax
    mov eax, dword[c]
    mul eax

    shl rdx, 32
    or rax, rdx

    ;work
    ; c^2 * b
    xor rbx, rbx
    movzx ebx, word[b]
    mul rbx

    shl rdx, 32
    or rax, rdx
    ;work
    ; d^2 - c^2 * b
    sub rcx, rax ; res in rcx
    xor rdx, rdx

    mov rax, r8
    div rcx

    mov [result], rax


    mov eax, 60
    xor edi, edi
    syscall


err:
    mov eax, 60
    mov edi, 1
    syscall
