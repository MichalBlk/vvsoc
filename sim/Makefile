standard:
	verilator -O3 --x-assign fast --x-initial fast --noassert -I../hw/sim \
		-I../hw/include -y ../hw -y ../hw/common -y ../hw/app -y ../hw/app/app_core \
		-y ../hw/app/app_core/mmu -y ../hw/virtio --cc top.sv -CFLAGS -O3 \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 \
		-Wno-WIDTH -Wno-CASEINCOMPLETE --exe tb.cpp --build

dbg:
	verilator --public -O0 -I../hw/sim -I../hw/include -y ../hw -y ../hw/common \
		-y ../hw/app -y ../hw/app/app_core -y ../hw/app/app_core/mmu -y ../hw/virtio \
		--cc top.sv -CFLAGS -ggdb -LDFLAGS -ggdb -CFLAGS -D_GLIBCXX_DEBUG \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 -Wno-WIDTH \
		-Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --exe tb_dbg.cpp --build

measure:
	verilator --public -O0 -I../hw/sim -I../hw/include -y ../hw -y ../hw/common \
		-y ../hw/app -y ../hw/app/app_core -y ../hw/app/app_core/mmu -y ../hw/virtio \
		--cc top.sv -CFLAGS -ggdb -LDFLAGS -ggdb -CFLAGS -D_GLIBCXX_DEBUG \
		-CFLAGS -I/usr/include/SDL2 -CFLAGS -D_REENTRANT -LDFLAGS -lSDL2 -Wno-WIDTH \
		-Wno-CASEINCOMPLETE -Wno-UNOPTFLAT --exe tb_measure.cpp --build

clean:
	rm -rf obj_dir

.PHONY: standard dbg measure clean
