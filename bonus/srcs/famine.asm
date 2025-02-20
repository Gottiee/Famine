%include "famine.inc"

bits 64
default rel

section .text
global _start

_start:
    mov rbp, rsp
    mov rdi, dir1                                       ; dir to open for arg initDir
    call _initDir
    jmp _exit

; take directory to open in rdi-> pwd
; rdx == 0 ? rien : recreate a path: rdi/rsi
_initDir:
    ; placing famine on the stack
    push rbp
    mov rbp, rsp
    sub rsp, famine_size
    lea rsi, FAM(famine.pwd)
    call _strcpy                                            ; strcpy(famine.pwd(rsi), pwd(rdi))
    cmp rdx, 0
    je _readDir
    call _strlen                                            ; strlen(famine.pwd(rsi))
    add rsi, rax
    cmp BYTE [rsi - 1], '/'
    je _join
    mov BYTE [rsi], '/'
    add rsi, 1

    _join:
    mov rdi, rdx
    call _strcpy

    ; debug
    ; mov rsi, rsp
    ; writeWork
    ; writeBack

    mov rdi, rsp

_readDir:
    mov rax, SYS_OPEN 
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl _return

    lea rdi, FAM(famine.fd)                             ; en registre le fd dans la struct
    mov [rdi], rax

    _getDents:
        lea r10, FAM(famine.fd) 
        lea r9, FAM(famine.total_read)                      ; init total_read
        mov DWORD[r9], 0
        mov rax, SYS_GETDENTS                   			; getdents64(int fd, void *buf, size_t size_buf)
        mov rdi, [r10]
        lea rsi, FAM(famine.dirents)
        mov rdx, PAGE_SIZE
        syscall
        cmp rax, 0
        jle _return

    lea r10, FAM(famine.dirents_struct_ptr) 			; r10 -> (struct famine.diretents_struct_ptr)
    mov [r10], rsi          	                		; famine.dirents_struct_ptr -> famine.dirents
    lea r11, FAM(famine.total_to_read)      			; r11 -> (struct famine.total_to_read)
    mov DWORD [r11], eax                        		; famine.total_to_read = getdents total length


    _listFile:
        lea r8, FAM(famine.total_read)      			; r8 -> total lu de getdents
        lea r9, FAM(famine.total_to_read)       		; r9 -> total a lire de getdents
        mov r10, FAM(famine.dirents_struct_ptr) 		; r10 -> actual dirent struct
        lea r11, FAM(famine.dirents_struct_ptr) 		; r11 -> ptr de la struct actuelle
        movzx r12, WORD [r10 + D_RECLEN_OFF] 			; r12 = length de la stuct dirents actuelle
        add [r8], r12d                        			; update du total lu dans r8
        add [r11], r12                          		; famine.diretns_struct_ptr -> sur la prochaine struct
        cmp BYTE [r10 + D_TYPE], D_FOLDER
        je _recursif
        cmp BYTE [r10 + D_TYPE], D_REG_FILE 			; verifie le type du fichier
        jne _checkRead

        ; debug
        mov rsi, rsp
        writeWork
        writeSlash

        lea rsi, [r10 + D_NAME]                 		; charge le nom du fichier dans rsi

        writeWork                               		; a modifier avec ta fonction
        writeBack
        jmp _checkRead

            _recursif:
                lea rdi, FAM(famine.pwd)
                lea rdx, [r10 + D_NAME]                 ; rdi -> folder name
                cmp BYTE [rdx], 0x2e
                jne _callInit
                cmp BYTE [rdx + 1], 0
                je _checkRead
                cmp BYTE [rdx + 1], 0x2e
                jne _callInit
                cmp BYTE [rdx + 2], 0
                je _checkRead

                _callInit:
                    call _initDir

            _checkRead:
                mov r8, FAM(famine.total_read)
                mov r12, FAM(famine.total_to_read)
                cmp r8d, r12d                 			; if (total lu >= total getdents)
                jge _getDents
                jmp _listFile
    

_return:
    mov rax, SYS_CLOSE
    mov rdi, FAM(famine.fd)
    syscall
    leave
    ret

;strcpy(dst:rsi src: rdi)
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
		mov byte [rsi + rcx], 0
		ret

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

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

dir1        db  "/", 0
back        db  10, 0
slash       db "/", 0