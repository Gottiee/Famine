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

- bouclé de maniere recursive sur les directories pour trouver les fichiers
- pour chaque fichier:
    - analyser si c'est un fichier qu'on peut infecter (elf 64)
    - chercher un gap, dans le fichier (meme tech qu'avec woody)
    - verifier si l'executable est deja infecté
    - verifier si le gap est assez gros (normalement ca devrait passer pour la pluspart des fichier (si c'et trop gros, il faudra soit optimiser, soit mettre en place un packer (compresser notre code pour qu'il rentre dasn la cave)))
    - patch l'entrypoint du binaire
    - injecter le code

## Amelioration possible:

- packer le virus
- faire en sorte pouvoir augmenter la taille du fichier d'une page 0x1000, en shiftant tous dans le fichier de 4096 byte apres notre cave.
- faire executer une backdoor
- le faire devenir recursif
- multi processus / threads (mdr les threads en asm)
- infecter des images

### Docu

- [Gitgub de ref](https://github.com/Croco-byte/famine)
