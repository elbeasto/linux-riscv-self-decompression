// SPDX-License-Identifier: GPL-2.0
/*
 * compressed/memmove.c
 *
 * This provides a memmove implementation needed by LZ4 decompression code.
 * Borrowed by arch/arm/compressed/string.c until an optimised version
 * is available in arch/riscv/lib/
 */

#include <linux/string.h>

void *memmove(void *__dest, __const void *__src, size_t count)
{
	unsigned char *d = __dest;
	const unsigned char *s = __src;

	if (__dest == __src)
		return __dest;

	if (__dest < __src)
		return memcpy(__dest, __src, count);

	while (count--)
		d[count] = s[count];
	return __dest;
}
