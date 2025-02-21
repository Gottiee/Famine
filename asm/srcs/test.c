#include <elf.h>

int	main( void )
{
	PT_LOAD; 
	PT_DYNAMIC;
	PT_NULL;
	PT_INTERP;
	PT_NOTE;
	PT_SHLIB;
	PT_PHDR;
	PT_LOPROC;
	PT_HIPROC;
	PT_GNU_STACK;
	PF_X;
	PF_W;
	PF_R;
}