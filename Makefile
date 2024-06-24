SHELL := /bin/bash
BIN   := riscv64-qemu
byteos = $(shell kbuild $(1) microkernel.yaml $(BIN) $(2))
byteos_config = $(call byteos,config,get_cfg $(1))
byteos_env = $(call byteos,config,get_env $(1))
byteos_meta = $(call byteos,config,get_meta $(1))
byteos_triple = $(call byteos,config,get_triple $(1))
NVME := off
NET  := off
LOG  := error
RELEASE := release
SMP := 1
QEMU_EXEC ?= 
GDB  ?= gdb-multiarch
ARCH := $(call byteos_triple,arch)
TARGET := $(call byteos_meta,target)

BUS  := device
ifeq ($(ARCH), x86_64)
  QEMU_EXEC += qemu-system-x86_64 \
				-machine q35 \
				-kernel $(KERNEL_ELF) \
				-cpu IvyBridge-v2
  BUS := pci
else ifeq ($(ARCH), riscv64)
  QEMU_EXEC += qemu-system-$(ARCH) \
				-machine virt \
				-kernel $(KERNEL_BIN)
else ifeq ($(ARCH), aarch64)
  QEMU_EXEC += qemu-system-$(ARCH) \
				-cpu cortex-a72 \
				-machine virt \
				-kernel $(KERNEL_BIN)
else ifeq ($(ARCH), loongarch64)
  QEMU_EXEC += qemu-system-$(ARCH) -kernel $(KERNEL_ELF)
  BUS := pci
else
  $(error "ARCH" must be one of "x86_64", "riscv64", "aarch64" or "loongarch64")
endif

KERNEL_ELF = target/$(TARGET)/$(RELEASE)/microkernel
KERNEL_BIN = target/$(TARGET)/$(RELEASE)/microkernel.bin
FS_IMG  := mount.img
features:= 
QEMU_EXEC += -m 1G\
			-nographic \
			-smp $(SMP) \
			-D qemu.log -d in_asm,int,pcall,cpu_reset,guest_errors

TESTCASE := testcase-$(ARCH)

ifeq ($(BLK), on)
QEMU_EXEC += -drive file=$(FS_IMG),if=none,format=raw,id=x0
	QEMU_EXEC += -device virtio-blk-$(BUS),drive=x0
endif

ifeq ($(NET), on)
QEMU_EXEC += -netdev user,id=net0,hostfwd=tcp::6379-:6379,hostfwd=tcp::2222-:2222,hostfwd=tcp::2000-:2000,hostfwd=tcp::8487-:8487,hostfwd=tcp::5188-:5188,hostfwd=tcp::12000-:12000 -object filter-dump,id=net0,netdev=net0,file=packets.pcap \
	-device virtio-net-$(BUS),netdev=net0
features += net
endif

all: build

fs-img:
	rm -f $(FS_IMG)
	dd if=/dev/zero of=$(FS_IMG) bs=1M count=40
	mkfs.vfat -F 32 $(FS_IMG)
	sync
	sudo mount $(FS_IMG) mount -o uid=1000,gid=1000
	touch mount/file123
	mkdir mount/dir123
	sudo umount mount

env:
	rustup component add llvm-tools-preview

build:
	kbuild build microkernel.yaml $(BIN)
	rust-objcopy --binary-architecture=$(ARCH) $(KERNEL_ELF) --strip-all -O binary $(KERNEL_BIN)

run: build
	time $(QEMU_EXEC)

# Lab1: TODO
# 增加对于Users目录的编译命令，让他可以编译user文件夹下的内容

run-user: 
	make build
	time $(QEMU_EXEC)

justrun: 
	rust-objcopy --binary-architecture=$(ARCH) $(KERNEL_ELF) --strip-all -O binary $(KERNEL_BIN)
	$(QEMU_EXEC)

fdt:
	$(QEMU_EXEC) -machine virt,dumpdtb=virt.out
	fdtdump virt.out

debug: build
	@tmux new-session -d \
	"$(QEMU_EXEC) -s -S && echo '按任意键继续' && read -n 1" && \
	tmux split-window -h "$(GDB) $(KERNEL_ELF) -ex 'target remote localhost:1234' -ex 'disp /16i $pc' " && \
	tmux -2 attach-session -d

clean:
	rm -rf target/ users/target

addr2line:
	addr2line -sfipe $(KERNEL_ELF) | rustfilt

fmt:
	cargo fmt
	cd users && cargo fmt

.PHONY: all run build clean gdb justbuild run-user fmt
