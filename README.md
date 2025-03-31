# Famine

## Injection technique

- Segment padding
- Elf shifting
    - https://github.com/jdecorte-be/42-WoodyWoodpacker
- PT_NOTE segment - .note.* section

https://www.root-me.org/fr/Documentation/Applicatif/ELF-Injection?q=%2Fen%2FDocumentation%2FApplicatif%2FELF-Injection

https://0x00sec.org/t/elfun-file-injector/410

https://medium.com/@dassomnath/handcrafting-x64-elf-from-specification-to-bytes-9986b342eb89 (il est fou afflelou)

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
```


## Fonctionnement:

- checker tous les fichiers dans les repertoir /tpm/test et /tmp/test2
- pour chaque fichier:
    - checker si c'est un fichier

    - analyser si c'est un fichier qu'on peut infecter (elf 64)
        - open
        - mmap
        - checker Ehdr
    - verifier si l'executable est deja infecté (jsp comment faire)
        - ?

    - chercher un gap, dans le fichier (meme tech qu'avec woody)
    - verifier si le gap est assez gros (normalement ca devrait passer pour la pluspart des fichier (si c'et trop gros, il faudra soit optimiser, soit mettre en place un packer (compresser notre code pour qu'il rentre dasn la cave)))
    - patch l'entrypoint du binaire + les segments
    - injecter le code

## Amelioration possible:

- [ ] packer le virus
- [x] faire executer une backdoor
- [x] privesc
- [x] le faire devenir recursif
- [x] Exctract des fichiers

### Docu

- [Gitgub de ref](https://github.com/Croco-byte/famine)
- [Autre reference](https://github.com/0x050f/famine)
- [asm references](https://www.felixcloutier.com/x86/)
- [another asm references](https://faydoc.tripod.com/cpu/jc.htm)

### GDB usefull commands
```b *(_start + 0x115)```: sets a breakpoint a certain offset

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

### A tester

- normal
	- mauvais magic bytes
	- mauvais droits
	- pas de cave assez grande
- bonus
	- pas de connexion au serveur


### TODO
	- Unmap bonus eliot