DTB_FILES = $(addsuffix .dtb,$(basename $(wildcard *.dts)))

all: $(DTB_FILES)

%.dtb: %.dts
	dtc -I dts -O dtb $< -o $@

clean:
	rm -rf $(DTB_FILES)

.PHONY: all clean
