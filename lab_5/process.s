bits 64

section .text

global desaturate

; void desaturate(uint8_t *pixels, int32_t width, int32_t height)
;
; rdi  - row pointer
; edx  - height counter
; rbx  - width        (callee-saved: push/pop)
; r12d - max / gray   (callee-saved: push/pop)
; rsi  - pixel pointer (inner loop)
; ecx  - column counter (inner loop)
; r8d  - B
; r9d  - G
; r10d - R
; r11d - min

desaturate:
        push    rbx
        push    r12

        test    rdi, rdi
        jz      .done
        test    esi, esi
        jle     .done
        test    edx, edx
        jle     .done

        mov     ebx, esi        ; rbx = width

.row_loop:
        mov     rsi, rdi        ; rsi = pixel pointer
        mov     ecx, ebx        ; ecx = width (column counter)

.col_loop:
        movzx   r8d,  byte [rsi]        ; B
        movzx   r9d,  byte [rsi + 1]    ; G
        movzx   r10d, byte [rsi + 2]    ; R

        ; max(B, G, R) -> r12d
        mov     r12d, r8d
        cmp     r9d,  r12d
        cmova   r12d, r9d
        cmp     r10d, r12d
        cmova   r12d, r10d

        ; min(B, G, R) -> r11d
        mov     r11d, r8d
        cmp     r9d,  r11d
        cmovb   r11d, r9d
        cmp     r10d, r11d
        cmovb   r11d, r10d

        ; gray = (max + min) >> 1
        add     r12d, r11d
        shr     r12d, 1

        mov     byte [rsi],     r12b
        mov     byte [rsi + 1], r12b
        mov     byte [rsi + 2], r12b

        add     rsi, 3
        dec     ecx
        jnz     .col_loop

        ; padding = (4 - (width*3) % 4) % 4
        ; stride  = width*3 + padding
        mov     eax, ebx        ; eax = width
        imul    eax, 3          ; eax = width*3
        mov     ecx, eax        ; ecx = width*3
        and     ecx, 3          ; ecx = (width*3) % 4
        neg     ecx             ; ecx = -(width*3 % 4)
        add     ecx, 4          ; ecx = 4 - (width*3 % 4)
        and     ecx, 3          ; ecx = padding
        add     eax, ecx        ; eax = stride
        add     rdi, rax

        dec     edx
        jnz     .row_loop

.done:
        pop     r12
        pop     rbx
        ret
