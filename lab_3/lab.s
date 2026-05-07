bits 64

section .data

    size equ 10 ; размер буфера


    err_arg_msg:
        db      "use: ./lab <outpue_file>", 10
    err_open_msg:
        db      "failed to open output file", 10
    err_read_msg:
        db      "read error", 10
    err_write_msg:
        db      "write error", 10
    err_brk_msg:
        db      "alloc error", 10


    len_err_arg     equ $-err_arg_msg
    len_err_open    equ $-err_open_msg
    len_err_read    equ $-err_read_msg
    len_err_write   equ $-err_write_msg
    len_err_brk     equ $-err_brk_msg

section .bss
    buffer_in resb 4096
    buffer_out resb 4096


section .text
global _start

_start:
    pop rcx
    cmp rcx, 2 ; сравниваем колво аргументов
    Je args_ok

    mov rsi, err_arg_msg
    mov rdx, len_err_arg
    call error

args_ok:
    pop rsi
    pop rsi; получаем имя файла

    mov rax, 2 ; sys_open
    mov rdi, rsi ; имя файла
    mov rsi, 0x241
    mov rdx, 0o666
    syscall

    cmp rax, 0
    jge file_ok

    mov rsi, err_open_msg
    mov rdx, len_err_open
    call error


file_ok:
    mov r15, rax


main_loop:
    call read_line

    cmp r12, 0 ; r12 длина строки
    je exit_ok

    call process_string

    call write_line

    jmp main_loop


exit_ok:
    mov rax, 60
    xor rdi, rdi
    syscall



read_line:
    xor r12, r12

.read_char:
    mov rax, 0 ; sys_read
    mov rdi, 0 ; читаем из stdin
    lea rsi, [buffer_in + r12]
    mov rdx, 1
    syscall

    cmp rax, 0 ; если прочитано 0 байт - конец файла
    je .eof

    cmp byte [buffer_in + r12], 10 ; проверка на энтр
    je .done

    inc r12 ; увеличиваем
    cmp r12, 4095 ; проверяяем переполнение
    jl .read_char

.done:
    ret ; возвращаемся

.eof:
    xor r12, r12
    ret


process_string:
    xor r8, r8
    xor r9, r9
    xor r10, r10
    xor r11, r11

.loop:
    cmp r8, r12 ; проверили все символы?
    jge .finish

    mov al, [buffer_in + r8] ; символ
    inc r8 ; переходим к следующему символуч

    cmp al, ' ' ; пробел?
    je .separator
    cmp al, 9 ; таб?
    je .separator
    cmp al, 10 ; перевод строки?
    je .separator


    test r10, 1 ; чекаем младший бит
    jnz .skip_char ; если 1 = нечет -> пропускаем

    mov [buffer_out + r9], al
    inc r9 ; увеличиваем счетчик
    mov r11, 1


.skip_char:
    inc r10 ; увеличиваем позицию в слове
    jmp .loop ; некст символ

.separator:
    xor r10, r10 ; сбрасываем позицию

    cmp r11, 0 ; если слово не началось
    je .loop
    ; вставляем пробел между словами
    cmp r9, 0 ; если входной буфер пуст - не вставляем
    je .loop
    cmp byte [buffer_out + r9 - 1], ' ' ; если последний символ пробел
    je .loop

    mov [buffer_out + r9], byte ' ' ; вставляем пробем
    inc r9
    jmp .loop

.finish:
    ;убираем лишний пробел в конце и добавляем перевод строки
    cmp r9, 0
    je .empty

    cmp byte [buffer_out + r9 - 1], ' '
    jne .no_space
    dec r9


.no_space:
    mov [buffer_out + r9], byte 10 ; добавляем \n
    inc r9

.empty:
    ret



write_line:
    cmp r9, 0 ; если строка пустая
    je  .nothing

    mov rax, 1 ; sys_write
    mov rdi, r15
    mov rsi, buffer_out ; адрес данных
    mov rdx, r9 ; длина данных
    syscall

    cmp rax, 0 ; проверяем успшност
    jge .nothing

    ;ошибка записи
    mov rsi, err_write_msg
    mov rdx, len_err_write
    call error

.nothing:
    ret


error:
    mov rax, 1 ;    sys_write
    mov rdi, 2;     stderr
    syscall

    mov rax, 60
    mov rdi, 1 ; код ошибки
    syscall
