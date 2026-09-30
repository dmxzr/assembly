bits 64

; void sobel_filter(const uint8_t *src, uint8_t *dst, int32_t width, int32_t height)
; rdi = src, rsi = dst, edx = width, ecx = height
;
; За одну итерацию SIMD обрабатываем 8 пикселей.
; Оставшиеся пиксели в конце строки обрабатываем скалярно.
;
; Трюк для |x| без pabsw (он только в SSSE3, не SSE2):
;   sign = x >> 15  — даёт 0x0000 если x >= 0, 0xFFFF если x < 0
;   |x|  = (x xor sign) - sign

section .text
global sobel_filter

sobel_filter:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8

    mov r12, rdi ; src
    mov r13, rsi ; dst
    mov r14d, edx ; width
    mov r15d, ecx ; height

    ; зануляем весь выходной буфер
    mov rdi, r13
    xor eax, eax
    mov ecx, r15d
    imul ecx, r14d
    rep stosb

    ; указатели строк для y=1
    mov rsi, r12 ; верхняя строка (y=0)
    lea rdi, [r12 + r14] ; средняя строка (y=1)
    lea r8, [rdi + r14] ; нижняя строка (y=2)
    lea r9, [r13 + r14] ; выходная (y=1)

    dec r15d ; r15d = height - 1 (граница y-цикла)
    mov r11d, r14d
    dec r11d ; r11d = width - 1 (граница скалярного хвоста)

    mov ebp, 1
.y_loop:
    cmp ebp, r15d
    jge .y_done

    ; r10d = width - 9: последний x при котором влезают 8 пикселей (x..x+7)
    mov r10d, r14d
    sub r10d, 9

    pxor xmm5, xmm5 ; xmm5 = 0, для расширения байт в слова

    mov ebx, 1
.simd_loop:
    cmp ebx, r10d
    jg .scalar_tail

    ; верхняя строка: загружаем 16 байт с позиции x-1
    movdqu xmm0, [rsi + rbx - 1] ; верх[x-1 .. x+14]
    movdqa xmm1, xmm0
    psrldq xmm1, 1 ; xmm1 = верх[x] (tc)
    movdqa xmm2, xmm0
    psrldq xmm2, 2 ; xmm2 = верх[x+1] (tr)
    punpcklbw xmm0, xmm5 ; xmm0 = tl
    punpcklbw xmm1, xmm5 ; xmm1 = tc
    punpcklbw xmm2, xmm5 ; xmm2 = tr

    ; Gy от верхней строки = -(tl + 2*tc + tr)
    movdqa xmm4, xmm1
    paddw xmm4, xmm1 ; 2*tc
    paddw xmm4, xmm0 ; + tl
    paddw xmm4, xmm2 ; + tr
    pxor xmm3, xmm3
    psubw xmm3, xmm4 ; xmm3 = -(tl + 2*tc + tr)

    ; Gx от верхней строки = tr - tl
    movdqa xmm4, xmm2
    psubw xmm4, xmm0 ; xmm4 = tr - tl

    ; средняя строка: только ml и mr (в ядре Gy там нули)
    movdqu xmm0, [rdi + rbx - 1]
    movdqa xmm1, xmm0
    psrldq xmm1, 2 ; сдвиг на 2 → mr
    punpcklbw xmm0, xmm5 ; xmm0 = ml
    punpcklbw xmm1, xmm5 ; xmm1 = mr

    ; Gx += 2*(mr - ml)
    psubw xmm1, xmm0
    paddw xmm1, xmm1
    paddw xmm4, xmm1

    ; нижняя строка: bl, bc, br
    movdqu xmm0, [r8 + rbx - 1]
    movdqa xmm1, xmm0
    movdqa xmm2, xmm0
    psrldq xmm1, 1 ; bc
    psrldq xmm2, 2 ; br
    punpcklbw xmm0, xmm5 ; xmm0 = bl
    punpcklbw xmm1, xmm5 ; xmm1 = bc
    punpcklbw xmm2, xmm5 ; xmm2 = br

    ; Gx += br - bl
    psubw xmm2, xmm0 ; xmm2 = br - bl
    paddw xmm4, xmm2 ; Gx готов

    ; Gy += bl + 2*bc + br
    ; т.к. xmm2 = br-bl: bl + 2*bc + br = 2*bl + 2*bc + (br-bl)
    paddw xmm0, xmm0 ; 2*bl
    paddw xmm1, xmm1 ; 2*bc
    paddw xmm0, xmm1 ; 2*bl + 2*bc
    paddw xmm0, xmm2 ; + (br-bl) = bl + 2*bc + br
    paddw xmm3, xmm0 ; Gy готов

    ; |Gx|
    movdqa xmm0, xmm4
    psraw xmm0, 15 ; маска знака
    pxor xmm4, xmm0
    psubw xmm4, xmm0 ; |Gx|

    ; |Gy|
    movdqa xmm0, xmm3
    psraw xmm0, 15
    pxor xmm3, xmm0
    psubw xmm3, xmm0 ; |Gy|

    ; магнитуда: packuswb насыщает значения > 255 до 255
    paddw xmm4, xmm3
    packuswb xmm4, xmm5 ; uint16 → uint8 с насыщением
    movq [r9 + rbx], xmm4 ; пишем 8 пикселей

    add ebx, 8
    jmp .simd_loop

; скалярный хвост — пиксели которые не влезли в SIMD
.scalar_tail:
.scalar_loop:
    cmp ebx, r11d
    jge .row_done

    ; Gx = (tr-tl) + 2*(mr-ml) + (br-bl)
    movzx eax, byte [rsi + rbx - 1] ; tl
    movzx ecx, byte [rsi + rbx + 1] ; tr
    sub ecx, eax
    movzx eax, byte [rdi + rbx - 1] ; ml
    movzx edx, byte [rdi + rbx + 1] ; mr
    sub edx, eax
    lea ecx, [ecx + edx*2]
    movzx eax, byte [r8 + rbx - 1] ; bl
    movzx edx, byte [r8 + rbx + 1] ; br
    sub edx, eax
    add ecx, edx ; ecx = Gx

    ; Gy = (bl-tl) + 2*(bc-tc) + (br-tr)
    movzx eax, byte [rsi + rbx - 1] ; tl
    movzx edx, byte [r8 + rbx - 1] ; bl
    sub edx, eax
    movzx eax, byte [rsi + rbx] ; tc
    movzx r10d, byte [r8 + rbx] ; bc
    sub r10d, eax
    lea edx, [edx + r10d*2]
    movzx eax, byte [rsi + rbx + 1] ; tr
    movzx r10d, byte [r8 + rbx + 1] ; br
    sub r10d, eax
    add edx, r10d ; edx = Gy

    test ecx, ecx
    jns .gx_done
    neg ecx
.gx_done:
    test edx, edx
    jns .gy_done
    neg edx
.gy_done:
    add ecx, edx
    cmp ecx, 255
    jle .no_clamp
    mov ecx, 255
.no_clamp:
    mov byte [r9 + rbx], cl
    inc ebx
    jmp .scalar_loop

.row_done:
    add rsi, r14
    add rdi, r14
    add r8, r14
    add r9, r14
    inc ebp
    jmp .y_loop

.y_done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
