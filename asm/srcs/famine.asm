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
    xor r8, r8
    lea r10, FAM(famine.dirents)            ; r10 -> (struct famine.diretents)
    mov r12, rax                            ; r12 = getdents total length
    cmp r12, 0
    jle _return

    _listFile:
        movzx r9, WORD [r10 + D_RECLEN_OFF] ; r9 = length de la stuct dirents actuelle
        add r8, r9                          ; update du total lu dans r8
        mov rbx, r10                        ; rbx -> struct dirent
        add r10, r9                         ; r10 -> sur la prochaine struct dirent
        cmp BYTE [rbx + D_TYPE], D_REG_FILE ; verifie le type du fichier
        jne _checkRead
        writeWork

            _checkRead:
            cmp r8, r12                     ; if (total lu >= total getdents)
            jge _return
            jmp _listFile

_return:
    ret

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

dir1        db  "../test", 0
open        db  "It worked", 10, 0