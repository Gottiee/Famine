%include "../inc/famine_anvincen.inc"

BITS	64

section	.text
global	_start

_start:
	
    ; placing famine on the stack
    mov rbp, rsp
	call _check_file
    jmp _exit

_check_file:
	push rbp
	mov	rbp, rsp
    sub rsp, check_file_size

	_open_file:
		mov	rax, SYS_OPEN
		lea	rdi, [rel file_name]
		mov rsi, O_RDWR
		xor rdx, rdx 
		syscall
		cmp	rax, qword 0x0
		jl	open_file_error
		mov CHF(check_file.file_fd), rax
		writeWork

	_get_file_size:
		mov rax, SYS_LSEEK
		mov	rdi, CHF(check_file.file_fd)
		mov	rsi, 0x0
		mov rdx, SEEK_END
		syscall
		mov r10, rax
		mov rax, SYS_LSEEK
		mov rdx, SEEK_SET
		syscall

	_map_file:
		mov rax, SYS_MMAP
		lea	rdi, 0x0
		mov rsi, r10
		mov rdx, PROT_READ | PROT_WRITE | PROT_EXEC
		mov r10, MAP_SHARED
		mov r8, CHF(check_file.file_fd)
		mov r9, 0x0
		syscall
		cmp	rax, 0x0
		jl _return
		mov CHF(check_file.map), rax

	_check_elf_format:
		inc rax
		cmp	dword [rax], 0x02464c45	; if != 'E'
		jne _exit_wrong_format


	_close_file:
		mov	rax, qword 0x3
		mov	rdi, CHF(check_file.file_fd)
		syscall
		jmp _return

	_exit_wrong_format:
		mov rax, 0x1
		jmp _return


open_file_error:
	jmp	_exit

_return:
	leave
	ret

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall
	
align 8
file_name	db	"sample64",0x0
open        db  "It worked", 10, 0
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	