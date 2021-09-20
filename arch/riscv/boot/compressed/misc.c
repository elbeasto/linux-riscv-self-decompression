// SPDX-License-Identifier: GPL-2.0
/*
 * compressed/misc.c
 *
 * Copyright (C) 2019 Xenia Ragiadakou <burzalodowa@gmail.com>
 */

#include <linux/types.h>
#include <linux/linkage.h>
#include <linux/string.h>
#include <linux/cpu.h>
#include <linux/elf.h>
#include <asm/sbi.h>
#include "misc.h"

/* The hart to first increment this variable will perform the decompression */
atomic_t hart_lottery;

unsigned char *output_data;
unsigned long free_mem_ptr;
unsigned long free_mem_end_ptr;

struct sbiret sbi_ecall(int ext, int fid, unsigned long arg0,
			unsigned long arg1, unsigned long arg2,
			unsigned long arg3, unsigned long arg4,
			unsigned long arg5)
{
	struct sbiret ret;

	register uintptr_t a0 asm ("a0") = (uintptr_t)(arg0);
	register uintptr_t a1 asm ("a1") = (uintptr_t)(arg1);
	register uintptr_t a2 asm ("a2") = (uintptr_t)(arg2);
	register uintptr_t a3 asm ("a3") = (uintptr_t)(arg3);
	register uintptr_t a4 asm ("a4") = (uintptr_t)(arg4);
	register uintptr_t a5 asm ("a5") = (uintptr_t)(arg5);
	register uintptr_t a6 asm ("a6") = (uintptr_t)(fid);
	register uintptr_t a7 asm ("a7") = (uintptr_t)(ext);
	asm volatile ("ecall"
		      : "+r" (a0), "+r" (a1)
		      : "r" (a2), "r" (a3), "r" (a4), "r" (a5), "r" (a6), "r" (a7)
		      : "memory");
	ret.error = a0;
	ret.value = a1;

	return ret;
}

void sbi_console_putchar(int ch)
{
	sbi_ecall(SBI_EXT_0_1_CONSOLE_PUTCHAR, 0, ch, 0, 0, 0, 0, 0);
}

void rvdecomp_putstr(const char *ptr)
{
	char c;

	while ((c = *ptr++) != '\0') {
		if (c == '\n')
			sbi_console_putchar('\r');
		sbi_console_putchar(c);
	}
}

void rvdecomp_puthex(unsigned long x)
{
	unsigned long i = 0, j = 0;
	unsigned long digit, digits[16];

	do {
		digits[j++] = x & 0xf;
		x >>= 4;
		i++;
	} while (x);

	while (j) {
		digit = digits[--j];
		if (digit < 10)
			sbi_console_putchar('0' + digit);
		else
			sbi_console_putchar('a' + (digit - 10));
	}
	sbi_console_putchar('\r');
	sbi_console_putchar('\n');
}

#ifndef arch_error
#define arch_error(x)
#endif

void error(char *x)
{
	arch_error(x);

	rvdecomp_putstr("\n\n");
	rvdecomp_putstr(x);
	rvdecomp_putstr("\n\n -- System halted");

	while (1)
		;
}


#define STATIC static
#define STATIC_RW_DATA	/* non-static please */

#ifdef CONFIG_KERNEL_GZIP
#include "../../../../lib/decompress_inflate.c"
#endif

#ifdef CONFIG_KERNEL_LZMA
#include "../../../../lib/decompress_unlzma.c"
#endif

#ifdef CONFIG_KERNEL_XZ
#define memmove memmove
#define memcpy memcpy
#include "../../../../lib/decompress_unxz.c"
#endif

#ifdef CONFIG_KERNEL_LZO
#include "../../../../lib/decompress_unlzo.c"
#endif

#ifdef CONFIG_KERNEL_LZ4
#include "../../../../lib/decompress_unlz4.c"
#endif

void rvdecomp_extract_kernel(unsigned long output_start,
			     unsigned long free_mem_ptr_p,
			     unsigned long free_mem_ptr_end_p)
{
	int ret;

	output_data		= (unsigned char *)output_start;
	free_mem_ptr		= free_mem_ptr_p;
	free_mem_end_ptr	= free_mem_ptr_end_p;

	rvdecomp_putstr("Decompressing Linux...\n");

	ret = __decompress(input_data_start, input_data_end - input_data_start,
			   NULL, NULL, output_data, 0, NULL, error);
	if (ret)
		error("decompressor returned an error");
	else
		rvdecomp_putstr(" done, booting the kernel.\n");
}
