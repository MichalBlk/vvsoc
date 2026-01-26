IMAGES     = ../images
TOOLS      = ../tools
BIN2MEM    = $(TOOLS)/bin2mem.py

MEM        = bootloader.mem opensbi.mem dt.mem kernel.mem initrd.mem virtio.mem
BOOTLOADER = $(IMAGES)/bootloader/bootloader.bin
OPENSBI    = $(IMAGES)/opensbi.bin
DT         = $(IMAGES)/linux/dt_hvc.dtb
KERNEL     = $(IMAGES)/linux/kernel.bin
INITRD     = $(IMAGES)/linux/initrd.cpio
VIRTIO     = $(IMAGES)/virtio.bin

standard: $(MEM)
	verilator -O3 --x-assign fast --x-initial fast --noassert -I../hw/sim \
		-I../hw/include -y ../hw -y ../hw/common -y ../hw/app -y ../hw/app/app_core \
		-y ../hw/app/app_core/mmu -y ../hw/virtio --cc top.sv -CFLAGS -O3 \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 \
		-Wno-WIDTH -Wno-CASEINCOMPLETE --exe tb.cpp --build

dbg: $(MEM)
	verilator --public -O0 -I../hw/sim -I../hw/include -y ../hw -y ../hw/common \
		-y ../hw/app -y ../hw/app/app_core -y ../hw/app/app_core/mmu -y ../hw/virtio \
		--cc top.sv -CFLAGS -ggdb -LDFLAGS -ggdb -CFLAGS -D_GLIBCXX_DEBUG \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 -Wno-WIDTH \
		-Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --exe tb_dbg.cpp --build

measure: $(MEM)
	verilator --public -O0 -I../hw/sim -I../hw/include -y ../hw -y ../hw/common \
		-y ../hw/app -y ../hw/app/app_core -y ../hw/app/app_core/mmu -y ../hw/virtio \
		--cc top.sv -CFLAGS -ggdb -LDFLAGS -ggdb -CFLAGS -D_GLIBCXX_DEBUG \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 -Wno-WIDTH \
		-Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --exe tb_measure.cpp --build

bootloader.mem: $(BOOTLOADER)
	$(BIN2MEM) $(BOOTLOADER) 4 $@

opensbi.mem: $(OPENSBI)
	$(BIN2MEM) $(OPENSBI) 1 $@

dt.mem: $(DT)
	$(BIN2MEM) $(DT) 1 $@

kernel.mem: $(KERNEL)
	$(BIN2MEM) $(KERNEL) 1 $@

initrd.mem: $(INITRD)
	$(BIN2MEM) $(INITRD) 1 $@

virtio.mem: $(VIRTIO)
	$(BIN2MEM) $(VIRTIO) 4 $@

clean:
	rm -rf obj_dir *.mem

.PHONY: standard dbg measure clean
