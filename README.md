# Famine

## Injection technique

- Cave injection
- [PT_NOTE to PT_LOAD injection](https://www.symbolcrash.com/2019/03/27/pt_note-to-pt_load-injection-in-elf/)

[How to make ELF mdr](https://medium.com/@dassomnath/handcrafting-x64-elf-from-specification-to-bytes-9986b342eb89)


## Cmd utiles

```sh
# read all
readelf -a
# file header
readelf -h
# read section
readelf -S
# read segment
readelf -l
# print raw opcode to check offsets errors
hexdump -C
```

### GDB usefull commands
```b *(_start + 0x115)```: sets a breakpoint a certain offset

## Method:
- Run trough all files in repertory
- For each one of them:
	- Check if it is a file
	- Check if it is an elf64 format by reading the potential elf64_ehdr :
		- Read the first bytes of it that specifies the format
	- Browse all segment:
		- Find a type PT_LOAD segment
		- Check the presence of a signature
		- Comparing the size of the gap between the segment and the following to our code:
			- gap bigger: we will infect that segment. We save the data refering to this segment
			- gap smaller: we turn a variable to one telling us more space will be needed
	- A big enough space was found:
		- save the old p_filesz: it becomes our injection offset (where we will write in the file)
		- update the header of this segment (filesz, memsz)
	- No sufficient space was found: (We will use the PT_NOTE to PT_LOAD method to create space)
		- Find a PT_NOTE segment
		- Update its header:
			- p_type: PT_NOTE -> PT_NOTE
			- p_flags -> PF_X | PF_R
			- p_offset -> end of file
			- p_vaddr -> end of program in memory:
				- We save it to update the e_hdr
			- p_size -> CODE_LEN
			- p_align -> PAGE_SIZE
	- Update the e_hdr:
		- update e_hdr.e_entry (note that it is an address offset and not a file offset (see readelf output))
	- Copy the virus
	- Update the final jump: jump back to the original code


### Docu

- [Gitgub de ref](https://github.com/Croco-byte/famine)
- [Autre reference](https://github.com/0x050f/famine)
- [asm references](https://www.felixcloutier.com/x86/)
- [another asm references](https://faydoc.tripod.com/cpu/jc.htm)

## Bonus

### Privesc + backdoor:

**Backdoor**: A backdoor is a hidden method of bypassing normal authentication to gain unauthorized access to a system.

**Privilege Escalation (PrivEsc)**: PrivEsc is the process of gaining higher permissions on a system, often by exploiting vulnerabilities or misconfigurations.

- The program try to write a public ssh key in `/root/.ssh/authorized_keys` (privesc)
- If it succed we can connect with our private key as a root (backdoor)

> This can happend when the user run a infected program with sudo

```sh
ssh -i /path/to/private/ssh/key root@192.1.1.1
```

### Recursif

The program recursively enters all directories to scan and infect every file.

### Data exfiltration

For each file it infects, the virus opens a socket and connects to a remote server. It then transmits the file's contents over the connection. This allows the attacker to exfiltrate data from the compromised system.

```sh
python3 python/server.py
```

### Control Spreading

By manipulate the global variable `infection = True` in [server.py](./bonus/python/server.py), you can stop the virus infection.

make sure to launch the server otherwise, the infection wont stop

```sh
python3 python/server.py
```
