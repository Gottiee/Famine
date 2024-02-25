#include "../include/famine.h"

void print_error(char *err, char *arg, t_arg_data *arg_data)
{
    if (!arg_data->debug)
        return;
    printf("Error: ");
    printf(err, arg);
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
        printf("%s\n", entity->d_name);
        if (entity->d_type == 4 && strcmp(entity->d_name, ".") && strcmp(entity->d_name, ".."))
        {
            char *new_path = malloc(sizeof(char) * (strlen(entity->d_name) + strlen(path) + 1));
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