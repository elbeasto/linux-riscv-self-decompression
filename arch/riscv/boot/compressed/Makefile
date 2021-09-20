# SPDX-License-Identifier: GPL-2.0
#
# compressed/Makefile
#
# Create a compressed image from the original kernel proper
#

AFLAGS_head.o += -DTEXT_OFFSET=$(TEXT_OFFSET)
HEAD	= head.o

OBJS	= misc.o

# string library code needed by decompressors
OBJS	+=  ../../lib/memcpy.o ../../lib/memset.o memmove.o string.o

efi-obj-$(CONFIG_EFI_STUB) := $(objtree)/drivers/firmware/efi/libstub/lib.a

compress-$(CONFIG_KERNEL_GZIP) = gzip
compress-$(CONFIG_KERNEL_LZO)  = lzo
compress-$(CONFIG_KERNEL_LZMA) = lzma
compress-$(CONFIG_KERNEL_XZ)   = xzkern
compress-$(CONFIG_KERNEL_LZ4)  = lz4

targets := vmlinux vmlinux.lds piggy_data piggy.o head.o $(OBJS)

clean-files += $(targets)

ccflags-y := -fno-builtin -fno-stack-protector

# Report unresolved symbol references
LDFLAGS_vmlinux := --no-undefined
# Delete all temporary local symbols
LDFLAGS_vmlinux += -X
# Next argument is a linker script
LDFLAGS_vmlinux += -T

$(obj)/vmlinux: $(obj)/vmlinux.lds $(obj)/$(HEAD) $(obj)/piggy.o \
                $(addprefix $(obj)/, $(OBJS)) $(efi-obj-y) FORCE
	$(call if_changed,ld)

$(obj)/piggy_data: $(obj)/../Image FORCE
	$(call if_changed,$(compress-y))

$(obj)/piggy.o: $(obj)/piggy_data
