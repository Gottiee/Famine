#include <fcntl.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <stdio.h>
#include <elf.h>
#include <unistd.h>

int	main ( void )
{
	int	elf_fd = open("sample64", O_RDWR);
	if (elf_fd == -1)
	{
		fprintf(stderr, "Open failed\n");
		exit(1);
	}
	printf("Sample64 opened\n");
	struct stat f_stat = {0};
	if (fstat(elf_fd, &f_stat) == -1)
		printf("fstat failed\n");
	printf("File size == %ld\n", f_stat.st_size);

	void	*elf_map = mmap(NULL, f_stat.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, elf_fd, 0);
	if (elf_map == MAP_FAILED)
	{
		fprintf(stderr, "mmap failed\n");
		exit (1);
	}
	printf("elf_map at 0x%x\n", elf_map);
	Elf64_Ehdr *ehdr = elf_map;
	printf("elf->e_ident == %s\n", ehdr->e_ident);

	ftruncate(elf_fd, f_stat.st_size + 0x1000);
	
	munmap(elf_map, f_stat.st_size);

	elf_map = mmap(NULL, f_stat.st_size + 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, elf_fd, 0);
	if (elf_map == MAP_FAILED)
	{
		fprintf(stderr, "mmap failed\n");
		exit (1);
	}
	

	return (0);
}