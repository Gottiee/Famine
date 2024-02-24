#include "../include/famine.h"

void init_struct(t_arg_data *arg_data)
{
    arg_data->maxThreads = 10;
    arg_data->folder = NULL;
}

void print_help()
{
    printf("Usage: ./Famine </path/to/folder>\n\t\"-h\", \"--help\": Print usage\n\t\"-t\", \"--threads\": Number of threads (max 20)\n");
    exit(0);
}

void print_struct(t_arg_data *arg_data)
{
    printf("Print struct\n");
    printf("\tFolder = \"%s\"\n",arg_data->folder);
    printf("\tMaxThreads = %d\n",arg_data->maxThreads);
}


void check_args(char **argv, t_arg_data *arg_data)
{
    int i = 0;

    while (argv[++i])
    {
        if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help"))
            print_help();
        else if ((!strcmp(argv[i], "-t") || !strcmp(argv[i], "--threads")) && argv[i + 1])
        {
            int threads = atoi(argv[i + 1]);
            threads = (threads > 20)? 10 : threads;
            arg_data->maxThreads = threads;
            i ++;
        }
        else
        {
            if (!arg_data->folder)
                arg_data->folder = argv[i];
        }

    }
    if (!arg_data->folder)
        arg_data->folder = "/tmp";
}

int main(int argc, char **argv)
{
    t_arg_data arg_data;
    (void)argc;

    init_struct(&arg_data);
    check_args(argv, &arg_data);
    print_struct(&arg_data);
}