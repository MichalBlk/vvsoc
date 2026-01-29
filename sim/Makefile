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

ac_test_imgs:
	$(BIN2MEM) $(IMAGES)/bootloader/bootloader_ac_test.bin 4 bootloader.mem
	$(BIN2MEM) $(IMAGES)/ac_test.bin 1 opensbi.mem
	$(BIN2MEM) $(IMAGES)/virtio.bin 4 virtio.mem

vc_test_imgs:
	$(BIN2MEM) $(IMAGES)/bootloader/idle.bin 4 bootloader.mem
	$(BIN2MEM) $(IMAGES)/vc_test.bin 4 virtio.mem

linux_imgs:
	$(BIN2MEM) $(BOOTLOADER) 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(DT) 1 dt.mem
	$(BIN2MEM) $(KERNEL) 1 kernel.mem
	$(BIN2MEM) $(INITRD) 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem

linux_ktest_imgs:
	$(BIN2MEM) $(BOOTLOADER) 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(DT) 1 dt.mem
	$(BIN2MEM) $(IMAGES)/linux/kernel_test.bin 1 kernel.mem
	$(BIN2MEM) $(INITRD) 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem

linux_utest_imgs:
	$(BIN2MEM) $(IMAGES)/bootloader/bootloader_medium.bin 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(IMAGES)/linux/dt_hvc_medium.dtb 1 dt.mem
	$(BIN2MEM) $(KERNEL) 1 kernel.mem
	$(BIN2MEM) $(IMAGES)/linux/initrd_test.cpio 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem

linux_utest_full_imgs:
	$(BIN2MEM) $(IMAGES)/bootloader/bootloader_large.bin 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(IMAGES)/linux/dt_hvc_large.dtb 1 dt.mem
	$(BIN2MEM) $(KERNEL) 1 kernel.mem
	$(BIN2MEM) $(IMAGES)/linux/initrd_test_full.cpio 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem

mimiker_imgs:
	$(BIN2MEM) $(BOOTLOADER) 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(IMAGES)/mimiker/dt.dtb 1 dt.mem
	$(BIN2MEM) $(IMAGES)/mimiker/kernel.bin 1 kernel.mem
	$(BIN2MEM) $(IMAGES)/mimiker/initrd.cpio 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem

mimiker_test_imgs:
	$(BIN2MEM) $(BOOTLOADER) 4 bootloader.mem
	$(BIN2MEM) $(OPENSBI) 1 opensbi.mem
	$(BIN2MEM) $(IMAGES)/mimiker/dt_test.dtb 1 dt.mem
	$(BIN2MEM) $(IMAGES)/mimiker/kernel.bin 1 kernel.mem
	$(BIN2MEM) $(IMAGES)/mimiker/initrd.cpio 1 initrd.mem
	$(BIN2MEM) $(VIRTIO) 4 virtio.mem


clean:
	rm -rf obj_dir

distclean: clean
	rm *.mem

.PHONY: standard dbg measure ac_test_imgs vc_test_imgs linux_imgs \
	linux_ktest_imgs linux_utest_imgs linux_utest_full_imgs mimiker_imgs \
	mimiker_test_imgs clean distclean
