# ============================================================
# Makefile — Lab 6: Фильтр Собеля
#
# Использование:
#   make IMPL=c        — C реализация (по умолчанию)
#   make IMPL=asm      — NASM scalar (без SIMD)
#   make IMPL=simd     — NASM SSE2
#   make OPT=-O0       — уровень оптимизации GCC (по умолчанию: -O2)
#   make clean         — удалить всё собранное
# ============================================================

CC        = gcc
NASM      = nasm
OPT      ?= -O2
CFLAGS    = -Wall -Wextra $(OPT) -std=c99
NASMFLAGS = -f elf64
TARGET    = sobel

IMPL ?= c

ifeq ($(IMPL),asm)
    IMPL_OBJ = sobel_asm.o
else ifeq ($(IMPL),simd)
    IMPL_OBJ = sobel_simd.o
else
    IMPL_OBJ = sobel_c.o
endif

OBJS = main.o image.o $(IMPL_OBJ)

# ============================================================

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^
	@echo ""
	@echo "Собрано: $(TARGET)  [IMPL=$(IMPL)  OPT=$(OPT)]"

main.o: main.c image.h sobel.h
	$(CC) $(CFLAGS) -c -o $@ $<

image.o: image.c image.h
	$(CC) $(CFLAGS) -c -o $@ $<

sobel_c.o: sobel_c.c sobel.h
	$(CC) $(CFLAGS) -c -o $@ $<

sobel_asm.o: sobel_asm.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

sobel_simd.o: sobel_simd.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

clean:
	rm -f *.o $(TARGET)
