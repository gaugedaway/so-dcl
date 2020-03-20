all: dcl

dcl: dcl.o
	ld -o dcl dcl.o

dcl.o: dcl.asm
	nasm -f elf64 -o $@ $^
