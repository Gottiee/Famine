; SYSCALL
%define     SYS_EXIT        60
%define     SYS_OPEN        2
%define     SYS_GETDENTS    217
%define     SYS_CLOSE       3


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

%define     PAGE_SIZE           0x1000

%define		FAM(x)				[(rbp - famine_size) + x]

struc famine
    .dirents:           resb    PAGE_SIZE
    .total_read:        resd    1
    .total_to_read:     resd    1
    .dirents_struct_ptr resq    1
endstruc

%macro writeWork 0
    mov rax, 1
    mov rdi, 1
    mov rsi, open
    mov rdx, 11
    syscall
%endmacro
