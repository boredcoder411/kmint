CC = clang
LD = ld.lld
OBJCOPY = llvm-objcopy
NASM = nasm

CFLAGS = -target i386-elf -ffreestanding -fno-pic -fno-pie -mno-red-zone \
         -Wall -Wextra -Werror -g -c -Istage2/
LDFLAGS = -m elf_i386 -T link.ld -nostdlib -static -o kernel.elf

BUILD = build
IMAGE = image.img

STAGE2_C = stage2/loader.c stage2/utils.c stage2/dev/vga.c stage2/io.c \
           stage2/dev/disk.c stage2/dev/serial.c stage2/fs.c stage2/mbr.c \
           stage2/cpu/interrupts/idt.c stage2/cpu/interrupts/isr.c \
           stage2/cpu/pic/pic.c stage2/cpu/pit/pit.c stage2/dev/keyboard.c \
           stage2/mem.c

STAGE2_ASM = stage2/start_loader.asm stage2/cpu/interrupts/idt.asm \
             stage2/cpu/interrupts/isr.asm

STAGE2_OBJS = $(patsubst stage2/%.c,$(BUILD)/%.o,$(STAGE2_C)) \
              $(patsubst stage2/%.asm,$(BUILD)/%_s.o,$(filter-out stage2/start_loader.asm,$(STAGE2_ASM))) \
              $(BUILD)/start_loader.o

all: stage2 stage1 image

$(BUILD):
	mkdir -p $(BUILD)

stage1: stage1/boot.asm | $(BUILD)
	$(NASM) -f bin stage1/boot.asm -o boot.bin

stage2: $(STAGE2_OBJS) | $(BUILD)
	$(LD) $(LDFLAGS) $(STAGE2_OBJS)
	$(OBJCOPY) --only-keep-debug kernel.elf kernel.sym
	$(OBJCOPY) -O binary kernel.elf kernel.bin

$(BUILD)/%.o: stage2/%.c | $(BUILD)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $< -o $@

$(BUILD)/start_loader.o: stage2/start_loader.asm | $(BUILD)
	@mkdir -p $(dir $@)
	$(NASM) -f elf $< -o $@

$(BUILD)/%_s.o: stage2/%.asm | $(BUILD)
	@mkdir -p $(dir $@)
	$(NASM) -f elf $< -o $@

image: stage1 stage2 boot.bin assets.wad mkpart
	@if [ ! -f boot.bin ]; then \
		echo "Error: boot.bin not found."; exit 1; \
	fi
	@if [ ! -f assets.wad ]; then \
		echo "Error: assets.wad not found."; exit 1; \
	fi
	dd if=/dev/zero of=$(IMAGE) bs=1M count=10
	dd if=boot.bin of=$(IMAGE) conv=notrunc
	$(BUILD)/mkpart $(IMAGE)
	LOOP_DEV=$$(sudo losetup --find --show $(IMAGE)); \
	sudo partprobe $$LOOP_DEV; \
	sudo dd if=assets.wad of=$${LOOP_DEV}p2; \
	sudo losetup -d $$LOOP_DEV
	@echo "Disk image created! Use xxd $(IMAGE) | less to inspect"

wad_tool: tools/wad_tool.c | $(BUILD)
	gcc -o $(BUILD)/wad_tool tools/wad_tool.c -Istage2/

mkpart: tools/mkpart.c | $(BUILD)
	gcc -o $(BUILD)/mkpart tools/mkpart.c -Istage2/

psf: tools/psf.c | $(BUILD)
	gcc -o $(BUILD)/psf tools/psf.c -Istage2/ $$(pkg-config --cflags --libs libpng)

assets.wad: psf wad_tool | $(BUILD)
	$(BUILD)/psf tools/font.png $(BUILD)/font.psf
	$(BUILD)/wad_tool pack assets.wad IWAD $(BUILD)/font.psf

clean:
	rm -rf $(BUILD)
	rm -f *.bin kernel.elf kernel.sym $(IMAGE)

.PHONY: all clean stage1 stage2 image wad_tool mkpart psf
