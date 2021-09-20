/* SPDX-License-Identifier: GPL-2.0 */
/*
 * compressed/piggy.S
 *
 * Creates an allocatable ELF section which includes the compressed kernel.
 *
 * Copyright (C) 2019 Xenia Ragiadakou <burzalodowa@gmail.com>
 */

	.section .piggydata,"a"

	.globl	input_data_start, input_data_end
input_data_start:
	.incbin	"arch/riscv/boot/compressed/piggy_data"
input_data_end:
