obj-m := vblk.o
vblk-y := main.o stats_vblk.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

.PHONY: all clean test

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

test: all
	sudo bash tests/run_tests.sh