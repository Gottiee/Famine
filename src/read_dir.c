#include "../include/famine.h"

void print_error(char *err, char *arg, t_arg_data *arg_data)
{
    if (!arg_data->debug)
        return;
    printf("Error: ");
    printf(err, arg);
}

void print_path(char *path, char *d_name, t_arg_data *data)
{
    if (!data->debug)
        return;
    if (strcmp(d_name, ".") && strcmp(d_name, ".."))
    printf("%s/%s\n", path, d_name);
}

void read_dir(t_arg_data *data, char *path)
{
    struct dirent* entity;

    DIR* dir = opendir(path);
    if (!dir)
    {
        print_error("No dir \"%s\"", path, data);
        exit(1);
    }
    entity = readdir(dir);
    while (entity)
    {
        print_path(path, entity->d_name, data);
        if (entity->d_type == 4 && strcmp(entity->d_name, ".") && strcmp(entity->d_name, ".."))
        {
            char *new_path = calloc(strlen(entity->d_name) + strlen(path) + 2, sizeof(char));
            strcat(new_path, path);
            strcat(new_path, "/");
            strcat(new_path, entity->d_name);
            read_dir(data, new_path);
            free(new_path);
        }
        entity = readdir(dir);
    }
    closedir(dir);
}