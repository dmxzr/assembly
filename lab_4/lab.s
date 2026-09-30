bits 64
; arsh x = ln(x + sqrt(x^2+1)) = sum[(-1)^n*(2n)!/(4^n*(n!)^2*(2n+1))*x^(2n+1)]
; Рекуррентность: term[n+1] = term[n] * (-x^2) * (2n+1) / (2*(n+1)*(2n+3))

section .data
msg_prompt_x:   db "input x (|x|<1): ", 0
msg_prompt_eps: db "input eps: ", 0
fmt_f:          db "%f", 0
msg_left:       db "left part:  %.10g", 10, 0
msg_right:      db "right part: %.10g", 10, 0
fmt_term:       db "term[%d] = %.10g", 10, 0
msg_err_x:      db "error: |x| must be less than 1", 10, 0
msg_err_argc:   db "usage: lab4 <output_file>", 10, 0
msg_err_fopen:  db "error: cannot open file", 10, 0
mode_w:         db "w", 0
const_one:      dd 1.0

section .text

; ── Локальные переменные my_arsh ──────────────────────────────────────────────
xs   equ 8          ; [rbp-8]  float x
epss equ xs+8       ; [rbp-16] float eps
nx2  equ epss+8     ; [rbp-24] float -x^2
trm  equ nx2+8      ; [rbp-32] float term
sm   equ trm+8      ; [rbp-40] float sum
; [rbp-52] используется для временного сохранения ecx (n) вокруг call

; my_arsh(rdi=дескриптор файла, xmm0=x, xmm1=eps) → xmm0=сумма ряда
my_arsh:
        push    rbp
        mov     rbp, rsp
        sub     rsp, 56         ; 7*8 байт локальных + выравнивание
        push    rbx
        mov     rbx, rdi        ; сохранить дескриптор файла

        movss   [rbp-xs],   xmm0    ; сохранить x
        movss   [rbp-epss], xmm1    ; сохранить eps

        ; проверка |x| < 1
        call    fabsf
        ucomiss xmm0, [const_one]
        jae     .error_x

        ; -x^2
        movss   xmm0, [rbp-xs]
        mulss   xmm0, xmm0
        xorps   xmm1, xmm1
        subss   xmm1, xmm0
        movss   [rbp-nx2], xmm1     ; -x^2

        ; инициализация: term=x, sum=0, n=0
        movss   xmm0, [rbp-xs]
        movss   [rbp-trm], xmm0     ; term = x (член n=0)
        xorps   xmm0, xmm0
        movss   [rbp-sm],  xmm0     ; sum = 0
        mov     ecx, 0              ; n = 0

.loop:
        ; sum += term
        movss   xmm0, [rbp-sm]
        addss   xmm0, [rbp-trm]
        movss   [rbp-sm], xmm0

        ; fprintf(file, "term[%d] = %.10g", n, (double)term)
        mov     dword [rbp-52], ecx
        mov     rdi, rbx
        mov     rsi, fmt_term
        mov     edx, ecx
        movss   xmm0, [rbp-trm]
        cvtss2sd xmm0, xmm0
        mov     eax, 1
        call    fprintf

        mov     ecx, dword [rbp-52]     ; восстановить n

        ; проверка |term| < eps
        movss   xmm0, [rbp-trm]
        call    fabsf
        ucomiss xmm0, [rbp-epss]
        jb      .done

        ; следующий член: term *= (-x^2) * (2n+1) / (2*(n+1)*(2n+3))
        mov     eax, ecx        ; n

        mov     edx, eax        ; числитель: 2n+1
        add     edx, edx
        inc     edx

        inc     eax             ; знаменатель: 2*(n+1)*(2n+3)
        add     eax, eax        ; 2*(n+1)
        mov     esi, ecx
        add     esi, esi
        add     esi, 3          ; 2n+3
        imul    eax, esi        ; 2*(n+1)*(2n+3)

        cvtsi2ss xmm1, edx      ; float(2n+1)
        cvtsi2ss xmm2, eax      ; float(знаменатель)

        movss   xmm0, [rbp-trm]
        mulss   xmm0, [rbp-nx2] ; term * (-x^2)
        mulss   xmm0, xmm1      ; * (2n+1)
        divss   xmm0, xmm2      ; / знаменатель
        movss   [rbp-trm], xmm0

        inc     ecx
        jmp     .loop

.done:
        movss   xmm0, [rbp-sm]
        pop     rbx
        leave
        ret

.error_x:
        mov     rdi, msg_err_x
        xor     eax, eax
        call    printf
        xorps   xmm0, xmm0
        pop     rbx
        leave
        ret


extern  printf
extern  scanf
extern  logf
extern  sqrtf
extern  fabsf
extern  fopen
extern  fprintf
extern  fclose

global  main

; ── Локальные переменные main ─────────────────────────────────────────────────
x_v   equ 8
eps_v equ x_v+8     ; = 16

main:
        push    rbp
        mov     rbp, rsp
        sub     rsp, eps_v      ; 16 байт для x и eps

        cmp     rdi, 2
        jne     .error_argc

        mov     rdi, [rsi+8]    ; argv[1]
        mov     rsi, mode_w
        call    fopen
        test    rax, rax
        jz      .error_fopen
        mov     rbx, rax        ; rbx = дескриптор файла

        ; ввод x
        mov     rdi, msg_prompt_x
        xor     eax, eax
        call    printf

        mov     rdi, fmt_f
        lea     rsi, [rbp-x_v]
        xor     eax, eax
        call    scanf

        ; ввод eps
        mov     rdi, msg_prompt_eps
        xor     eax, eax
        call    printf

        mov     rdi, fmt_f
        lea     rsi, [rbp-eps_v]
        xor     eax, eax
        call    scanf

        ; проверка |x| < 1
        movss   xmm0, [rbp-x_v]
        call    fabsf
        ucomiss xmm0, [const_one]
        jae     .error_x

        ; левая часть: logf(x + sqrtf(x^2 + 1))
        movss   xmm0, [rbp-x_v]
        mulss   xmm0, xmm0
        addss   xmm0, [const_one]   ; x^2 + 1
        call    sqrtf
        addss   xmm0, [rbp-x_v]     ; x + sqrt(x^2+1)
        call    logf
        cvtss2sd xmm0, xmm0
        mov     rdi, msg_left
        mov     eax, 1
        call    printf

        ; правая часть через ряд
        mov     rdi, rbx
        movss   xmm0, [rbp-x_v]
        movss   xmm1, [rbp-eps_v]
        call    my_arsh

        cvtss2sd xmm0, xmm0
        mov     rdi, msg_right
        mov     eax, 1
        call    printf

        mov     rdi, rbx
        call    fclose

        xor     eax, eax
        leave
        ret

.error_x:
        mov     rdi, msg_err_x
        xor     eax, eax
        call    printf
        mov     rdi, rbx
        call    fclose
        mov     eax, 1
        leave
        ret

.error_fopen:
        mov     rdi, msg_err_fopen
        xor     eax, eax
        call    printf
        mov     eax, 1
        leave
        ret

.error_argc:
        mov     rdi, msg_err_argc
        xor     eax, eax
        call    printf
        mov     eax, 1
        leave
        ret
