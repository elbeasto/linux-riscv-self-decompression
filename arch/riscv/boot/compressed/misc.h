/* SPDX-License-Identifier: GPL-2.0 */
/*
 * compressed/misc.h
 *
 * Copyright (C) 2019 Xenia Ragiadakou <burzalodowa@gmail.com>
 */

#ifndef RISCV_MISC_H
#define RISCV_MISC_H

#include <linux/compiler.h>

void error(char *x) __noreturn;
extern unsigned long free_mem_ptr;
extern unsigned long free_mem_end_ptr;

/* Global declarations for inflated kernel start and end in piggy.S */
extern char input_data_start[];
extern char input_data_end[];

#endif
