# Famine

## TODO

- [ ] checker l'endianess du programm pour implementer la bonne string
- [ ] stocker la string dans le bon sens et faire une fonction qui swap sont endiannes
- [ ] faire un miniscript qui regenere le directory de test

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

### Recap

- C'est mieux d'ecrire tout le projet en assembleur

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
- [ ] faire executer une backdoor
- [ ] privesc
- [x] le faire devenir recursif
- [ ] Exctract des fichiers

### Docu

- [Gitgub de ref](https://github.com/Croco-byte/famine)
- [Autre reference](https://github.com/0x050f/famine)
- [asm references](https://www.felixcloutier.com/x86/)
- [another asm references](https://faydoc.tripod.com/cpu/jc.htm)

### GDB usefull commands
```b *(_start + 0x115)```: sets a breakpoint a certain offset

### A tester

- normal
	- mauvais magic bytes
	- mauvais droits
	- pas de cave assez grande
- bonus
	- pas de connexion au serveur