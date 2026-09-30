AS      = nasm
LD      = ld

ASCENDING ?= 1
ASFLAGS   = -f elf64 -DASCENDING=$(ASCENDING)

EXE = matrix
OBJ = matrix.o
SRC = matrix.asm

.PHONY: all clean run

all: $(EXE)

$(EXE): $(OBJ)
	$(LD) $< -o $@

$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) $< -o $@

run: $(EXE)
	./$(EXE)

clean:
	rm -f $(OBJ) $(EXE)
