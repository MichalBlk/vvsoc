PREFIX  = riscv32-unknown-linux-gnu-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
WFLAGS  = -Wall -Wextra
CFLAGS  = -std=gnu11 -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -fomit-frame-pointer
LDFLAGS = -T ./linker.ld

AC_OBJS = $(addprefix tests/ac_, $(addsuffix .o, $(notdir $(basename $(wildcard tests/*.S)))))
VC_OBJS = $(addprefix tests/vc_, $(addsuffix .o, $(notdir $(basename $(wildcard tests/*.S)))))

all: ac_test.bin vc_test.bin

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

ac_test.elf: ac_start.o $(AC_OBJS) linker.ld
	@echo $(AC_OBJS)
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) ac_start.o $(AC_OBJS) -o $@

vc_test.elf: vc_start.o $(VC_OBJS) linker.ld
	@echo $(VC_OBJS)
	$(CC) $(WFLAGS) $(CFLAGS) $(LDFLAGS) vc_start.o $(AC_OBJS) -o $@

ac_start.o: start.S
	$(CC) $(WFLAGS) $(CFLAGS) -DAC $< -c -o $@

vc_start.o: start.S
	$(CC) $(WFLAGS) $(CFLAGS) -DVC $< -c -o $@

tests/ac_%.o: tests/%.S tests/riscv_test.h tests/test_macros.h
	$(CC) $(WFLAGS) $(CFLAGS) -DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' \
		-DTEST_FUNC_RET=$(notdir $(basename $<))_ret \
		-DAC $< -c -o $@

tests/vc_%.o: tests/%.S tests/riscv_test.h tests/test_macros.h
	$(CC) $(WFLAGS) $(CFLAGS) -DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' \
		-DTEST_FUNC_RET=$(notdir $(basename $<))_ret \
		-DVC $< -c -o $@

clean:
	rm -rf ac_test.bin vc_test.bin ac_test.elf vc_test.elf \
		ac_start.o vc_start.o $(AC_OBJS) $(VC_OBJS)

.PHONY: all clean
