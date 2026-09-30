AS  = /usr/bin/nasm
CC  = /usr/bin/gcc

ASFLAGS = -f elf64 -g
OPT     = -O0
CFLAGS  = -Wall -g $(OPT)

all: lab_c lab_s

# C-версия функции desaturate
lab_c: main.o process_c.o
	$(CC) main.o process_c.o -o $@

# ASM-версия функции desaturate
lab_s: main.o process_s.o
	$(CC) main.o process_s.o -o $@

main.o: main.c
	$(CC) $(CFLAGS) -c main.c -o $@

process_c.o: process.c
	$(CC) $(CFLAGS) -c process.c -o $@

process_s.o: process.s
	$(AS) $(ASFLAGS) process.s -o $@

test_c: test.c process.c
	$(CC) $(CFLAGS) test.c process.c -o $@ && ./$@

test_s: test.c process_s.o
	$(CC) $(CFLAGS) test.c process_s.o -o $@ && ./$@

clean:
	rm -rf *.o lab_c lab_s test_c test_s
