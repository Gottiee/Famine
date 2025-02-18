NAME = open_file

LD = ld
NASM = nasm

SRCS =	$(addsuffix .asm, $(addprefix srcs/, open_file))

OBJS = ${SRCS:.asm=.o}

all:		$(NAME)

$(NAME):	$(OBJS)
			$(LD)  -o $(NAME) $(OBJS) 

%.o:%.asm
			$(NASM) -f elf64 -i srcs/ $< -o $@

# strife:
# 			nasm -f elf64 -i srcs/strife/ srcs/strife/strife.asm -o srcs/strife/strife.o && ld srcs/strife/strife.o -o Strife

clean:
				rm -f $(OBJS)

fclean:
				rm -f $(OBJS)
				rm -f $(NAME)
# rm -f Strife
# rm -f srcs/strife/strife.o

re:				fclean all

.PHONY:			all clean fclean re