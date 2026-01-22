TOOLS                 = ../../tools
BIN2MEM               = $(TOOLS)/bin2mem.py

PREFIX                = riscv32-unknown-linux-gnu-
CC                    = $(PREFIX)gcc
OBJCOPY               = $(PREFIX)objcopy
WFLAGS                = -Wall -Wextra
CFLAGS                = -std=gnu11 -O3 -ffreestanding -nostdlib -I../include -fomit-frame-pointer
LDFLAGS               = -T ./linker.ld

HEADERS            = $(wildcard ../include/*.h)
SRCS               = start.o main.o
SRCS_MEDIUM        = $(addsuffix _medium.o, $(basename $(SRCS)))
SRCS_LARGE         = $(addsuffix _large.o, $(basename $(SRCS)))
SRCS_AC_TEST       = $(addsuffix _ac_test.o, $(basename $(SRCS)))

INITRD_SIZE        = 0x600000
INITRD_MEDIUM_SIZE = 0x1000000
INITRD_LARGE_SIZE  = 0x3000000

all: bootloader.mem bootloader_medium.mem bootloader_large.mem bootloader_ac_test.mem

%.mem: %.bin
	$(BIN2MEM) 4 $^

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

bootloader.elf: $(SRCS) linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCS) -o $@

bootloader_medium.elf: $(SRCS_MEDIUM) linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCS_MEDIUM) -o $@

bootloader_large.elf: $(SRCS_LARGE) linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCS_LARGE) -o $@

bootloader_ac_test.elf: $(SRCS_AC_TEST) linker.ld
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) $(SRCS_AC_TEST) -o $@

start.o: start.S $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_SIZE) -c $< -o $@

start_medium.o: start.S $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_MEDIUM_SIZE) -c $< -o $@

start_large.o: start.S $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_LARGE_SIZE) -c $< -o $@

start_ac_test.o: start.S $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DAC_TEST -c $< -o $@

main.o: main.c $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_SIZE) -c $< -o $@

main_medium.o: main.c $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_MEDIUM_SIZE) -c $< -o $@

main_large.o: main.c $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DINITRD_SIZE=$(INITRD_LARGE_SIZE) -c $< -o $@

main_ac_test.o: main.c $(HEADERS)
	$(CC) $(WFLAGS) $(CFLAGS) -DAC_TEST -c $< -o $@

clean:
	rm -rf *mem *.bin *.elf *.o

.PHONY: all clean
.PRECIOUS: %.bin
