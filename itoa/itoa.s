bits 64
default rel

section .bss
    buffer resb 20

section .text
global _start

_start:
    mov rax, 1254
    mov rsi, buffer
    call _itoa

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; int itoa(rax:int, rsi:*buffer)
; (a la fin rsi pointe sur le byte d'apres)
_itoa:
    mov r9, 10
    call _itoaLoop
    ret

    _itoaLoop:
        cmp rax, 9
        jg _itoaRecursif
        mov [rsi], ax
        add byte [rsi], 48
        inc rsi
        ret

    _itoaRecursif:
        push rax
        xor rdx, rdx
        div r9
        call _itoaLoop 
        pop rax
        push rax
        xor rdx, rdx
        div r9
        mov rax, rdx
        call _itoaLoop 
        pop rax
        ret