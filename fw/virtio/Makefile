TOOLS   = ../../tools
BIN2MIF = $(TOOLS)/bin2mif.sh

PREFIX  = riscv32-unknown-linux-gnu-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
WFLAGS  = -Wall -Wextra
CFLAGS  = -std=gnu11 -O3 -ffreestanding -nostdlib -I../include -fomit-frame-pointer
LDFLAGS = -T ./linker.ld

HEADERS = $(wildcard ../include/*.h)
SRCS    = start.o main.o

virtio.mif: virtio.bin
	$(BIN2MIF) 4 $^

virtio.bin: virtio.elf
	$(OBJCOPY) -O binary $^ $@

virtio.elf: $(SRCS) linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

start.o: start.S $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -c $< -o $@

main.o: main.c $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -c $< -o $@

clean:
	rm -rf virtio.mif virtio.bin virtio.elf start.o main.o

.PHONY: clean
