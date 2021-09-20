/* SPDX-License-Identifier: GPL-2.0 */
/*
 * compressed/head.S
 *
 * Low-level startup code of the composite kernel image
 *
 * Copyright (C) 2019 Xenia Ragiadakou <burzalodowa@gmail.com>
 */

#include <asm/asm-offsets.h>
#include <asm/asm.h>
#include <linux/init.h>
#include <linux/linkage.h>
#include <asm/thread_info.h>
#include <asm/page.h>
#include <asm/pgtable.h>
#include <asm/csr.h>
#include <asm/hwcap.h>
#include <asm/image.h>
#include "efi-header.S"

__HEAD		/* .section	".head.text","ax" */
ENTRY(_start)
	/*
	 * Image header expected by Linux boot-loaders. The image header data
	 * structure is described in asm/image.h.
	 * Do not modify it without modifying the structure and all bootloaders
	 * that expects this header format!!
	 */
#ifdef CONFIG_EFI
	/*
	 * This instruction decodes to "MZ" ASCII required by UEFI.
	 */
	c.li s4,-13
	j _start_kernel
#else
	/* jump to start kernel */
	j _start_kernel
	/* reserved */
	.word 0
#endif

	/* reserved */
	.balign	8
#if __riscv_xlen == 64
	/* Image load offset(2MB) from start of RAM */
	.dword	0x200000
#else
	/* Image load offset(4MB) from start of RAM */
	.dword	0x400000
#endif
	/* Effective size of kernel image */
	.dword	_end - _start
	.dword	__HEAD_FLAGS
	.word	RISCV_HEADER_VERSION
	.word	0
	.dword 	0
	.ascii	RISCV_IMAGE_MAGIC
	.balign	4
	.ascii	RISCV_IMAGE_MAGIC2
#ifdef CONFIG_EFI
	.word pe_head_start - _start
pe_head_start:

	__EFI_PE_HEADER
#else
	.word 0
#endif

.Lsecondary_park:
	/* We lack SMP support or have too many harts, so park this hart */
	wfi
	j .Lsecondary_park

END(_start)

ENTRY(_start_kernel)
	/* Mask all interrupts */
	csrw CSR_IE, zero
	csrw CSR_IP, zero

	/* Load the global pointer */
.option push
.option norelax
	la 	gp, __global_pointer$
.option pop

	la 	sp, __stack_pointer$

	/*
	 * Disable FPU to detect illegal usage of
	 * floating point in kernel space
	 */
	li t0, SR_FS
	csrc CSR_STATUS, t0

#ifdef CONFIG_SMP
	li t0, CONFIG_NR_CPUS
	blt a0, t0, .Lgood_cores
	tail .Lsecondary_park
.Lgood_cores:
#endif

	/* Save hart ID and DTB physical address, in s0 and s1, respectively */
	mv	s0, a0
	mv	s1, a1

	/* Pick one hart to run the decompression sequence */
	la	a3, hart_lottery
	li	a2, 1
	amoadd.w a3, a2, (a3)
	bnez	a3, .Lsecondary_start

	/* Clear BSS */
	la a3, __bss_start
	la a4, __bss_stop
	ble a4, a3, .Lclear_bss_done
.Lclear_bss:
	REG_S zero, (a3)
	add a3, a3, RISCV_SZPTR
	blt a3, a4, .Lclear_bss
.Lclear_bss_done:

	la      a0, _start
	call    rvdecomp_puthex
	la      a0, hart_str
	call    rvdecomp_putstr
	mv      a0, s0
	call    rvdecomp_puthex

	/* Load inflated kernel size, which is appended to piggydata, in s2 */
	lw	s2, __piggy_size_addr
	/* Print inflated kernel size */
	la	a0, kernelsz_str
	call	rvdecomp_putstr
	mv	a0, s2
	call	rvdecomp_puthex

	/* Load DTB size in s3, in little-endian */
	lbu	t3, 4(s1)
	lbu	t4, 5(s1)
	lbu	t5, 6(s1)
	lbu	t6, 7(s1)
	slli	t3, t3, 24
	slli    t4, t4, 16
	slli    t5, t5, 8
	add	s3, t4, t3
	add	s3, s3, t5
	add	s3, s3, t6
	/* Print DTB size */
	la	a0, dtbsz_str
	call	rvdecomp_putstr
	mv	a0, s3
	call	rvdecomp_puthex

	/* At this point:
	 * s0	hart ID
	 * s1	DTB
	 * s2	inflated kernel size
	 * s3	DTB size
	 */

	/* Reserve 64K mem alloc region after the DTB */
	mv	s4, s1
	add	s4, s4, s3	/* load mem alloc start in s4 */
	lui	s8, 16
	add	s5, s4, s8	/* load mem alloc end in s5 */

	/* Place the inflated kernel after the mem alloc region */
	mv	s6, s5
#if __riscv_xlen == 64
	lui	s8, 0x200	/* align to 0x200000 for RV64I*/
#else
	lui	s8, 0x400	/* align to 0x400000 for RV32I*/
#endif
	addi	s8, s8, -1
	add	s6, s6, s8
	not	s8, s8
	and	s6, s6, s8	/* load decompression dst addr in s6 */

	/* Print dst address for the inflated kernel */
	la	a0, kerneladdr_str
	call	rvdecomp_putstr
	mv	a0, s6
	call	rvdecomp_puthex

	/* At this point:
	 * s0	hart ID
	 * s1	DTB
	 * s2	inflated kernel size
	 * s3	DTB size
	 * s4	mem alloc start
	 * s5	mem alloc end
	 * s6	kernel extraction dst addr
	 */

	/* Relocate DTB at the end of the uncompressed kernel */
	add	s7, s6, s2	/* store end of inflated kernel in s7 */
	lui	s8, 1		/* align to PAGE_SIZE */
	addi	s8, s8, -1
	add	s7, s7, s8
	not	s8, s8
	and	s7, s7, s8
	/* Print new DTB address */
	la	a0, relocated_dtbaddr_str
	call	rvdecomp_putstr
	mv	a0, s7
	call	rvdecomp_puthex

	mv	s9, s1		/* store old DTB addr to s9 */
	mv	s1, s7		/* save new DTB addr in s1 */
	add	s10, s1, s3	/* store end of relocated DTB in s10 */

.Lcopy:
	REG_L	s8, (s9)	/* copy from the old DTB */
	REG_S	s8, (s7)	/* to the new DTB */
	add	s9, s9, RISCV_SZPTR
	add	s7, s7, RISCV_SZPTR
	blt	s7, s10, .Lcopy

	/* Perform the decompression */
	mv	a0, s6
	mv	a1, s4
	mv	a2, s5
	call	rvdecomp_extract_kernel

	fence.i

	/* Place inflated kernel address into the return address register */
	mv	ra, s6

	/* Restore hart ID in a0 and place new DTB physical address in a1 */
	mv	a0, s0
	mv	a1, s1

	/* Zero all registers, except a0, a1 and ra */
	mv	a2, zero
	mv	a3, zero
	mv	a4, zero
	mv	a5, zero
	mv	a6, zero
	mv	a7, zero
	mv	t0, zero
	mv	t1, zero
	mv	t2, zero
	mv	t3, zero
	mv	t4, zero
	mv	t5, zero
	mv	t6, zero
	mv	s0, zero
	mv	s1, zero
	mv	s2, zero
	mv	s3, zero
	mv	s4, zero
	mv	s5, zero
	mv	s6, zero
	mv	s7, zero
	mv	s8, zero
	mv	s9, zero
	mv	s10, zero
	mv	s11, zero

	/* Wakeup other harts */
	la	a3, hart_lottery
	amoswap.w a3, zero, (a3)

	ret

.Lsecondary_start:
#ifdef CONFIG_SMP
	li	a1, CONFIG_NR_CPUS
	bgeu	a0, a1, .Lsecondary_park

	la	a3, hart_lottery
	li	a2, 1
.Lwait_for_cpu_up:
	amoand.w a4, a2, (a3)
	bnez	a4, .Lwait_for_cpu_up

	la      a0, hart_str
	call    rvdecomp_putstr
	mv      a0, s0
	call    rvdecomp_puthex

	/* Restore hart ID in a0 and place new DTB physical address in a1 */
	mv	a0, s0
	mv	a1, s1

	/* Zero other used registers */
	mv	a2, zero
	mv	s0, zero
	mv	s1, zero

	nop
	nop
	nop

	REG_L	ra, output_data
	ret
#endif

kernelsz_str:
	.asciz "inflated_kernel_sz="
kerneladdr_str:
	.asciz "inflated_kernel_addr="
dtbsz_str:
	.asciz "dtb_sz="
relocated_dtbaddr_str:
	.asciz "relocated_dtb_addr="
hart_str:
	.asciz "hart="

END(_start_kernel)

	.section ".stack", "aw", %nobits
.Lstack:	.space	4096


