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

typedef struct s_arg_data
{
    char *folder;
    int maxThreads;
} t_arg_data;

#endif