#include "../include/famine.h"

void print_error(char *err, char *arg, t_arg_data *arg_data)
{
    if (!arg_data->debug)
        return;
    printf("Error: ");
    printf(err, arg);
}

void read_dir(t_arg_data *data)
{
    DIR* dir = opendir(data->folder);
    if (dir == NULL)
    {
        print_error("No dir \"%s\"", data->folder, data);
        exit(1);
    }

    struct dirent* entity;
    entity = readdir(dir);
    while (!entity)
    {
        printf("%s\n", entity->d_name);
        entity = readdir(dir);
    }
    closedir(dir);
}