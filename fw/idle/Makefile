TOOLS   = ../../tools
BIN2MEM = $(TOOLS)/bin2mem.py

PREFIX  = riscv32-unknown-linux-gnu-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
WFLAGS  = -Wall -Wextra
CFLAGS  = -std=gnu11 -O3 -ffreestanding -nostdlib -I../include -fomit-frame-pointer
LDFLAGS = -T ./linker.ld

idle.mem: idle.bin
	$(BIN2MEM) 4 $^

idle.bin: idle.elf
	$(OBJCOPY) -O binary $^ $@

idle.elf: start.o linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $< -o $@

start.o: start.S ../include/asm.h
	$(CC) $(WFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -rf idle.mem idle.bin idle.elf start.o

.PHONY: clean
