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
%define		D_NAME_OFF			0x12
%define     D_REG               0x8

%define     PAGE_SIZE           0x1000

%define		FAM(x)				[(rbp - famine_size) + x]
%define		CHF(x)				[(rbp - check_file_size) + x]

%define		ELF_TYPE_OFF		0x10

%define		SEEK_SET			0x0
%define		SEEK_END			0x2

struc famine
    .dirents:       resb        PAGE_SIZE
    .d_reclen:      resw        1
endstruc

struc check_file
	.file_fd:	resd	1
	.map:		resq	1
endstruc

%macro writeWork 0
    mov rax, 1
    mov rdi, 1
    mov rsi, open
    mov rdx, 11
    syscall
%endmacro
