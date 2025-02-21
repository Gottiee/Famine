%include "famine.inc"

bits 64
default rel

section .text
global _start

_start:

    ; placing famine on the stack
    mov rbp, rsp
    mov rdi, dir1                                   ; dir to open for arg readDir
    mov rsi, dir1Len
    call _readDir

    ; debug
    writeBack
    mov rsi, tiret
    writeWork
    writeBack
    writeBack

    mov rdi, dir2
    mov rsi, dir2Len
    call _readDir
    jmp _exit

; take directory to open in rdi && size of pwd on rsi
_readDir:
    push rbp
    mov rbp, rsp
    sub rsp, famine_size
    lea r8, FAM(famine.pwdPtr)
    mov [r8], rdi
    lea r8, FAM(famine.lenghtPwd)
    mov [r8], rsi
    mov rax, SYS_OPEN 
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl _exit
    lea rdi, FAM(famine.fd)                         ; enregistre le fd dans la struct
    mov [rdi], rax

    _getDents:
        lea r10, FAM(famine.fd)
        mov rdi, [r10]
        lea r9, FAM(famine.total_read)              ; init total_read
        mov DWORD[r9], 0
        mov rax, SYS_GETDENTS                   	; getdents64(int fd, void *buf, size_t size_buf)
        lea rsi, FAM(famine.dirents)
        mov rdx, PAGE_SIZE
        syscall
        cmp rax, 0
        jle _returnReadir

        lea r10, FAM(famine.dirents_struct_ptr) 	; r10 -> (struct famine.diretents_struct_ptr)
        mov [r10], rsi          	                ; famine.dirents_struct_ptr -> famine.dirents
        lea r11, FAM(famine.total_to_read)      	; r11 -> (struct famine.total_to_read)
        mov DWORD [r11], eax                        ; famine.total_to_read = getdents total length

    _listFile:
        lea r8, FAM(famine.total_read)      		; r8 -> total lu de getdents
        lea r9, FAM(famine.total_to_read)       	; r9 -> total a lire de getdents
        mov r10, FAM(famine.dirents_struct_ptr) 	; r10 -> actual dirent struct
        lea r11, FAM(famine.dirents_struct_ptr) 	; r11 -> ptr de la struct actuelle
        movzx r12, WORD [r10 + D_RECLEN_OFF] 		; r12 = length de la stuct dirents actuelle
        add [r8], r12d                        		; update du total lu dans r8
        add [r11], r12                          	; famine.diretns_struct_ptr -> sur la prochaine struct
        cmp BYTE [r10 + D_TYPE], D_REG_FILE 		; verifie le type du fichier
        jne _checkRead

        _updatePath:
            lea rsi, [r10 + D_NAME]                 	; charge le nom du fichier dans rsi
            mov byte [rsi - 1], '/'
            sub rsi, FAM(famine.lenghtPwd)
            mov rdi, FAM(famine.pwdPtr)
            call _strcpy

            ;debug
            writeWork
            writeBack
            
            ;met ta fonction ici

        _checkRead:
            mov r8, FAM(famine.total_read)
            mov r12, FAM(famine.total_to_read)
            cmp r8d, r12d                 		; if (total lu >= total getdents)
            jge _getDents
            jmp _listFile

_returnReadir:
    mov rax, SYS_CLOSE
    mov rdi, FAM(famine.fd)
    syscall
    leave
    ret

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

;strcpy(dst:rsi src: rdi) (without /0 at the end)
_strcpy:
	xor rcx, rcx
	strcpy_loop:
		cmp byte [rdi + rcx], 0
		je	strcpy_loop_end
		mov al, byte [rdi + rcx]
		mov [rsi + rcx], al
		add rcx, 1
		jmp strcpy_loop

	strcpy_loop_end:
		; mov byte [rsi + rcx], 0
		ret

; debug
; strlen(str:rsi)
_strlen:
	xor rcx, rcx
	
	ft_strlen_loop:
		cmp	byte [rsi + rcx], 0
		je	ft_strlen_end
		inc rcx
		jmp	ft_strlen_loop

	ft_strlen_end:
		mov rax, rcx
		ret

dir1        db  "../test", 0
dir1Len    equ $ - dir1
dir2        db  "../test/ok", 0
dir2Len    equ $ - dir2

;debug
tiret       db  "..---..",0
back        db  10, 0
