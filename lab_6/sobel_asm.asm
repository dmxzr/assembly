; sobel_asm.asm — Sobel edge detection, pure scalar NASM, Linux x64
;
; Соглашение о вызовах System V AMD64:
;   Аргументы:        RDI, RSI, EDX, ECX
;   Сохраняет вызываемый (callee-saved): RBX, RBP, R12-R15
;   Свободно использовать (caller-saved): RAX, RCX, RDX, RSI, RDI, R8-R11
;
; void sobel_filter(const uint8_t *src, uint8_t *dst, int width, int height)
;   RDI  = src     — указатель на исходные пиксели
;   RSI  = dst     — указатель на выходные пиксели
;   EDX  = width   — ширина изображения
;   ECX  = height  — высота изображения
;
; Ядра Собеля:
;   Gx: [-1  0  +1]     Gy: [-1  -2  -1]
;       [-2  0  +2]         [ 0   0   0]
;       [-1  0  +1]         [+1  +2  +1]
;
; Магнитуда: |Gx| + |Gy|, зажатая в [0, 255]

section .text
global sobel_filter

sobel_filter:
    ; ---- Пролог: сохраняем callee-saved регистры ----
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    ; После CALL: RSP % 16 = 8 (адрес возврата занимает 8 байт)
    ; 6 push × 8 байт = 48 байт: RSP % 16 = 8 (48 кратно 16)
    ; sub rsp, 8 → RSP % 16 = 0 (выравнивание)
    sub     rsp, 8

    ; ---- Сохраняем аргументы в callee-saved регистры ----
    mov     r12, rdi        ; r12 = src
    mov     r13, rsi        ; r13 = dst
    mov     r14d, edx       ; r14d = width (старшие 32 бита r14 автоматически = 0)
    mov     r15d, ecx       ; r15d = height

    ; ---- Зануляем весь выходной буфер сразу ----
    ; Собель пишет только во внутренние пиксели — граница останется нулями
    mov     rdi, r13        ; rdi = dst
    xor     eax, eax        ; al  = 0
    mov     ecx, r15d
    imul    ecx, r14d       ; ecx = width * height (количество байт)
    rep     stosb           ; заполняем нулями

    ; ==============================================================
    ; Основной цикл: y от 1 до height-2
    ; ==============================================================

    ; Инициализируем указатели строк один раз для y=1
    mov     rsi, r12            ; rsi = src + 0*width  (верхняя строка)
    lea     rdi, [r12 + r14]    ; rdi = src + 1*width  (средняя строка)
    lea     r8,  [rdi + r14]    ; r8  = src + 2*width  (нижняя строка)
    lea     r9,  [r13 + r14]    ; r9  = dst + 1*width  (выходная строка)

    ; Границы циклов — считаем один раз
    mov     r10d, r15d
    dec     r10d                ; r10d = height - 1
    mov     r11d, r14d
    dec     r11d                ; r11d = width  - 1

    mov     ebp, 1              ; y = 1
.y_loop:
    cmp     ebp, r10d
    jge     .y_done

    ; ----------------------------------------------------------
    ; Внутренний цикл: x от 1 до width-2
    ; ----------------------------------------------------------
    mov     ebx, 1          ; x = 1
.x_loop:
    cmp     ebx, r11d
    jge     .x_done

    ; ---- Gx = (tr - tl) + 2*(mr - ml) + (br - bl) ----
    movzx   eax, byte [rsi + rbx - 1]   ; tl = верх[x-1]
    movzx   ecx, byte [rsi + rbx + 1]   ; tr = верх[x+1]
    sub     ecx, eax                     ; tr - tl

    movzx   eax, byte [rdi + rbx - 1]   ; ml = середина[x-1]
    movzx   edx, byte [rdi + rbx + 1]   ; mr = середина[x+1]
    sub     edx, eax
    lea     ecx, [ecx + edx*2]           ; Gx += 2*(mr - ml)

    movzx   eax, byte [r8  + rbx - 1]   ; bl = низ[x-1]
    movzx   edx, byte [r8  + rbx + 1]   ; br = низ[x+1]
    sub     edx, eax
    add     ecx, edx                     ; ecx = Gx

    ; ---- Gy = (bl - tl) + 2*(bc - tc) + (br - tr) ----
    movzx   eax,  byte [rsi + rbx - 1]  ; tl
    movzx   edx,  byte [r8  + rbx - 1]  ; bl
    sub     edx, eax                     ; bl - tl

    movzx   eax,  byte [rsi + rbx]      ; tc = верх[x]
    movzx   r10d, byte [r8  + rbx]      ; bc = низ[x]
    sub     r10d, eax
    lea     edx,  [edx + r10d*2]         ; Gy += 2*(bc - tc)

    movzx   eax,  byte [rsi + rbx + 1]  ; tr
    movzx   r10d, byte [r8  + rbx + 1]  ; br
    sub     r10d, eax
    add     edx, r10d                    ; edx = Gy

    ; ---- |Gx| ----
    test    ecx, ecx
    jns     .gx_done    ; уже положительный — пропускаем neg
    neg     ecx
.gx_done:

    ; ---- |Gy| ----
    test    edx, edx
    jns     .gy_done    ; уже положительный — пропускаем neg
    neg     edx
.gy_done:

    ; ---- Магнитуда, зажатая в [0, 255] ----
    add     ecx, edx
    cmp     ecx, 255
    jle     .no_clamp
    mov     ecx, 255
.no_clamp:
    mov     byte [r9 + rbx], cl

    inc     ebx
    jmp     .x_loop
.x_done:

    ; Сдвигаем все указатели на одну строку вниз
    add     rsi, r14
    add     rdi, r14
    add     r8,  r14
    add     r9,  r14

    inc     ebp
    jmp     .y_loop
.y_done:

    ; ---- Эпилог: восстанавливаем регистры ----
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret
