PREFIX  = riscv32-unknown-linux-gnu-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
WFLAGS  = -Wall -Wextra
CFLAGS  = -std=gnu11 -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -fomit-frame-pointer

AC_SRCS = \
	add.S \
	addi.S \
	and.S \
	andi.S \
	auipc.S \
	beq.S \
	bge.S \
	bgeu.S \
	blt.S \
	bltu.S \
	bne.S \
	div.S \
	divu.S \
	j.S \
	jal.S \
	jalr.S \
	lb.S \
	lbu.S \
	lh.S \
	lhu.S \
	lui.S \
	lw.S \
	mul.S \
	mulh.S \
	mulhsu.S \
	mulhu.S \
	or.S \
	ori.S \
	rem.S \
	remu.S \
	sb.S \
	sh.S \
	simple.S \
	sll.S \
	slli.S \
	slt.S \
	slti.S \
	sra.S \
	srai.S \
	srl.S \
	srli.S \
	sub.S \
	sw.S \
	xor.S \
	xori.S

VC_SRCS = \
	add.S \
	addi.S \
	and.S \
	andi.S \
	auipc.S \
	beq.S \
	bge.S \
	bgeu.S \
	blt.S \
	bltu.S \
	bne.S \
	j.S \
	jal.S \
	jalr.S \
	lb.S \
	lbu.S \
	lh.S \
	lhu.S \
	lui.S \
	lw.S \
	or.S \
	ori.S \
	sb.S \
	sh.S \
	simple.S \
	sll.S \
	slli.S \
	slt.S \
	slti.S \
	sra.S \
	srai.S \
	srl.S \
	srli.S \
	sub.S \
	sw.S \
	xor.S \
	xori.S

AC_OBJS = $(addprefix tests/ac_, $(addsuffix .o, $(basename $(AC_SRCS))))
VC_OBJS = $(addprefix tests/vc_, $(addsuffix .o, $(basename $(VC_SRCS))))

all: ac_test.bin vc_test.bin

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

ac_test.elf: ac_start.o $(AC_OBJS) ac_linker.ld
	@echo $(AC_OBJS)
	$(CC) $(WFLAGS) $(CFLAGS) -T ./ac_linker.ld ac_start.o $(AC_OBJS) -o $@

vc_test.elf: vc_start.o $(VC_OBJS) vc_linker.ld
	@echo $(VC_OBJS)
	$(CC) $(WFLAGS) $(CFLAGS) -T ./vc_linker.ld vc_start.o $(VC_OBJS) -o $@

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
