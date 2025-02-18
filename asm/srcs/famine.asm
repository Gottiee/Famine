%include "famine.inc"

bits 64
default rel

section .text
global _start


_start:

    ; placing famine on the stack
    mov rbp, rsp
    sub rsp, famine_size
    call _readDir
    jmp _exit

_readDir:
    mov rax, SYS_OPEN
    mov rdi, dir1
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl _exit

    mov rdi, rax
    mov rax, SYS_GETDENTS
    lea rsi, FAM(famine.dirents)
    mov rdx, PAGE_SIZE
    syscall
    cmp rax, 0
    jle _return

    _listFile:
    lea rsi, FAM(famine.dirents)
    lea r8, FAM(famine.d_reclen)    ; r8 -> le total lu
    movzx r9, word [r8]             ; r9 = total length read
    add rsi, r9                     ; rsi -> sur la prochain struct de fichier

    mov r10, rsi                    ; r10 -> sur la prochain struct de fichier
    add r10, D_RECLEN_OFF           ; r10 -> la taille de la struct de fichier

    ; ajout du total lu
    mov r11w, word [r10]            ; r11 = la taille de la struct de fichier
    add word [r8], r11w             ; le total lu est update

    movzx r12, word [r8]            ; bouge dans r12 la valeur total lu
    sub rax, r12
    sub r11, 1
    add rsi, r11                    ; rsi -> le prochain (pour recup le d_type)
    movzx r13, byte [rsi]
    cmp r13, D_REG                  ; est ce que le fichier, est un fichier reg
    jne _checkRead
    writeWork
    jmp _checkRead

        _checkRead:
        cmp rax, 0
        jle _return
        jmp _listFile

_return:
    ret

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

dir1        db  "../test", 0
open        db  "It worked", 10, 0