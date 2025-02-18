%include "famine.inc"

bits 64
default rel

section .text
global _start


_start:

    ; placing famine on the stack
    mov rbp, rsp
    sub rsp, famine_size
    mov rdi, dir1                               ; dir to open for arg readDir
    call _readDir
    jmp _exit

; take directory to open in rdi
_readDir:
    mov rax, SYS_OPEN 
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl _exit

    mov rdi, rax
    mov rax, SYS_GETDENTS                   	; getdents64(int fd, void *buf, size_t size_buf)
    lea rsi, FAM(famine.dirents)
    mov rdx, PAGE_SIZE
    syscall
    lea r10, FAM(famine.dirents_struct_ptr) 	; r10 -> (struct famine.diretents_struct_ptr)
    mov [r10], rsi          	                ; famine.dirents_struct_ptr -> famine.dirents
    lea r11, FAM(famine.total_to_read)      	; r11 -> (struct famine.total_to_read)
    mov DWORD [r11], eax                        ; famine.total_to_read = getdents total length
    cmp rax, 0
    jle _return

    _listFile:
        lea r8, FAM(famine.total_read)      	; r8 -> total lu de getdents
        lea r9, FAM(famine.total_to_read)       ; r9 -> total a lire de getdents
        mov r10, FAM(famine.dirents_struct_ptr) ; r10 -> actual dirent struct
        lea r11, FAM(famine.dirents_struct_ptr) ; r11 -> ptr de la struct actuelle
        movzx r12, WORD [r10 + D_RECLEN_OFF] 	; r12 = length de la stuct dirents actuelle
        add [r8], r12d                        	; update du total lu dans r8
        add [r11], r12                          ; famine.diretns_struct_ptr -> sur la prochaine struct
        cmp BYTE [r10 + D_TYPE], D_REG_FILE 	; verifie le type du fichier
        jne _checkRead
        lea rsi, [r10 + D_NAME]                 ; charge le nom du fichier dans rsi
        writeWork                               ; a modifier avec ta fonction

            _checkRead:
                mov r8, FAM(famine.total_read)
                mov r12, FAM(famine.total_to_read)
                cmp r8d, r12d                 	; if (total lu >= total getdents)
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