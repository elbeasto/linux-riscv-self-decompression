/* SPDX-License-Identifier: GPL-2.0 */
/*
 * compressed/vmlinux.lds.S
 *
 * Copyright (C) 2019 Xenia Ragiadakou <burzalodowa@gmail.com>
 */

#include <asm/pgtable.h>
#define LOAD_OFFSET KERNEL_LINK_ADDR

#include <asm/vmlinux.lds.h>
#include <asm/page.h>
#include <asm/cache.h>
#include <asm/thread_info.h>
#include <asm/set_memory.h>
#include "image-vars.h"

#include <linux/sizes.h>

OUTPUT_ARCH(riscv)
ENTRY(_start)

PECOFF_SECTION_ALIGNMENT = 0x1000;
PECOFF_FILE_ALIGNMENT = 0x200;

SECTIONS
{
	/* Beginning of code and text segment */
	. = LOAD_OFFSET;
	_start = .;
	HEAD_TEXT_SECTION

	/* Text section */
	. = ALIGN(PAGE_SIZE);
	_stext = .;
	.text : AT(ADDR(.text) - LOAD_OFFSET) {
		*(.text)
	}
	/* compressed image is here, appended is the decompressed kernel size */
	. = ALIGN(PAGE_SIZE);
	.piggydata : AT(ADDR(.piggydata) - LOAD_OFFSET) {
		*(.piggydata)
		__piggy_size_addr = . - 4;
	}
#ifdef CONFIG_EFI
	. = ALIGN(PECOFF_SECTION_ALIGNMENT);
	__pecoff_text_end = .;
#endif
	_etext = .;

	/* Data section */
	. = ALIGN(PAGE_SIZE);
	_sdata = .;
	.rodata : AT(ADDR(.rodata) - LOAD_OFFSET) {
		*(.rodata*)
	}
	. = ALIGN(PAGE_SIZE);
	.data : AT(ADDR(.data) - LOAD_OFFSET) {
		__global_pointer$ = . + 0x800;
		*(.data*)
	}
#ifdef CONFIG_EFI
	.pecoff_edata_padding : { BYTE(0); . = ALIGN(PECOFF_FILE_ALIGNMENT); }
	__pecoff_data_raw_size = ABSOLUTE(. - __pecoff_text_end);
#endif
	_edata = .;

	BSS_SECTION(PAGE_SIZE, PAGE_SIZE, 0)

	. = ALIGN(PAGE_SIZE);
	.stack : AT(ADDR(.stack) - LOAD_OFFSET) {
		*(.stack*)
		__stack_pointer$ = .;
	}

#ifdef CONFIG_EFI
	. = ALIGN(PECOFF_SECTION_ALIGNMENT);
	__pecoff_data_virt_size = ABSOLUTE(. - __pecoff_text_end);
#endif
	_end = .;

	STABS_DEBUG
	DWARF_DEBUG
	ELF_DETAILS

	DISCARDS
}
