TOOLCHAIN_PREFIX=riscv32-unknown-linux-gnu-
TEST_OBJS = $(addsuffix .o,$(basename $(wildcard tests/*.S)))

tests.bin: tests.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

tests.elf: start.o $(TEST_OBJS) linker.ld
	@echo $(TEST_OBJS)
	$(TOOLCHAIN_PREFIX)gcc -Os -mabi=ilp32 -march=rv32im -ffreestanding -nostdlib -o $@ \
		-T linker.ld start.o $(TEST_OBJS) -lgcc

start.o: start.S
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32im -o $@ $<

tests/%.o: tests/%.S tests/riscv_test.h tests/test_macros.h
	$(TOOLCHAIN_PREFIX)gcc -c -mabi=ilp32 -march=rv32im -o $@ -DTEST_FUNC_NAME=$(notdir $(basename $<)) \
		-DTEST_FUNC_TXT='"$(notdir $(basename $<))"' -DTEST_FUNC_RET=$(notdir $(basename $<))_ret $<

clean:
	rm -rf tests.bin tests.elf start.o $(TEST_OBJS)

.PHONY: clean
