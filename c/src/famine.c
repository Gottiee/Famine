#include "../include/famine.h"

void init_struct(t_arg_data *arg_data)
{
    arg_data->maxThreads = 10;
    arg_data->folder = NULL;
    arg_data->debug = false;
}

void print_help()
{
    printf("Usage: ./Famine </path/to/folder>\n");
    printf("\t\"-h\", \"--help\": Print usage\n");
    printf("\t\"-t\", \"--threads\": Number of threads (max 20)\n");
    printf("\t\"-d\", \"--debug\": Print debug / error\n");
    exit(0);
}

void print_struct(t_arg_data *arg_data)
{
    if (!arg_data->debug)
        return;
    printf("Print struct\n");
    printf("\tFolder = \"%s\"\n",arg_data->folder);
    printf("\tMaxThreads = %d\n",arg_data->maxThreads);
    printf("\tDebug = %s\n", arg_data->debug ? "true" : "false");
    printf("\n");
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
        else if ((!strcmp(argv[i], "-d") || !strcmp(argv[i], "--debug")))
            arg_data->debug = true;
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
    // endiannes + 8 byte  (64 bits)
    const char *string = "\x76\x20\x65\x6e\x69\x6d\x61\x46\x31\x20\x6e\x6f\x69\x73\x72\x65\x64\x6f\x29\x63\x28\x20\x30\x2e\x32\x2d\x62\x65\x66\x20\x64\x65\x65\x20\x79\x62\x20\x35\x32\x30\x69\x76\x6e\x61\x2d\x79\x64\x65\x6e\x65\x63\x6e";

    printf("string endiannesed = %s\n\n", string);

    t_arg_data arg_data;
    (void)argc;

    init_struct(&arg_data);
    check_args(argv, &arg_data);
    print_struct(&arg_data);
    read_dir(&arg_data, arg_data.folder);
}