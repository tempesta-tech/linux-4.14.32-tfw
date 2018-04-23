/**
 * AVX implementation of memcmp() returning only true/false.
 *
 * Copyright (C) 2018 Tempesta Technologies, Inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 * See http://www.gnu.org/licenses/lgpl.html .
 */
#include <linux/linkage.h>
#include <asm/alternative-asm.h>
#include <asm/export.h>

ENTRY(__memcmp_avx)
	leaq	(%rdi,%rdx), %rax
	leaq	128(%rdi), %rcx
	cmpq	%rcx, %rax
	jnb	.L128cmp_loop
	movq	%rdi, %rcx
.L64tail:
	testb	$64, %dl
	jne	.L64cmp
.L32tail:
	testb	$32, %dl
	jne	.L32cmp
.L16tail:
	testb	$16, %dl
	jne	.L16cmp
.L8tail:
	testb	$8, %dl
	jne	.L8cmp
.L4tail:
	testb	$4, %dl
	jne	.L4cmp
.L2tail:
	testb	$2, %dl
	jne	.L2cmp
.L1tail:
	xorl	%eax, %eax
	andl	$1, %edx
	jne	.L1cmp
	ret
	.p2align 4
.L128cmp:
	vlddqu	-96(%rcx), %ymm0
	vlddqu	32(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %edi
	cmpl	$-1, %edi
	jne	.Lret_neq
	vlddqu	-64(%rcx), %ymm0
	vlddqu	64(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %edi
	cmpl	$-1, %edi
	jne	.Lret_neq
	vlddqu	-32(%rcx), %ymm0
	vlddqu	96(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %edi
	addl	$1, %edi
	jne	.Lret_neq
	leaq	128(%rcx), %rdi
	subq	$-128, %rsi
	cmpq	%rdi, %rax
	jb	.L64tail
	movq	%rdi, %rcx
.L128cmp_loop:
	vlddqu	-128(%rcx), %ymm0
	vlddqu	(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %edi
	cmpl	$-1, %edi
	je	.L128cmp
.Lret_neq:
	movl	$1, %eax
	ret
.L64cmp:
	vlddqu	(%rcx), %ymm0
	vlddqu	(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %eax
	cmpl	$-1, %eax
	jne	.Lret_neq
	vlddqu	32(%rcx), %ymm0
	vlddqu	32(%rsi), %ymm1
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %eax
	cmpl	$-1, %eax
	jne	.Lret_neq
	addq	$64, %rcx
	addq	$64, %rsi
	jmp	.L32tail
.L32cmp:
	vlddqu	(%rcx), %ymm0
	vlddqu	(%rsi), %ymm1
	movl	$1, %eax
	vpcmpeqd %ymm1, %ymm0, %ymm0
	vpmovmskb %ymm0, %edi
	cmpl	$-1, %edi
	jne	.Lret
	addq	$32, %rcx
	addq	$32, %rsi
	jmp	.L16tail
.L16cmp:
	vlddqu	(%rcx), %xmm0
	vlddqu	(%rsi), %xmm1
	movl	$1, %eax
	vpcmpeqw %xmm1, %xmm0, %xmm0
	vpmovmskb %xmm0, %edi
	cmpl	$65535, %edi
	jne	.Lret
	addq	$16, %rcx
	addq	$16, %rsi
	jmp	.L8tail
.L8cmp:
	movq	(%rsi), %rax
	cmpq	%rax, (%rcx)
	jne	.Lret_neq
	addq	$8, %rcx
	addq	$8, %rsi
	jmp	.L4tail
.L4cmp:
	movl	(%rsi), %eax
	cmpl	%eax, (%rcx)
	jne	.Lret_neq
	addq	$4, %rcx
	addq	$4, %rsi
	jmp	.L2tail
.L2cmp:
	movzwl	(%rsi), %eax
	cmpw	%ax, (%rcx)
	jne	.Lret_neq
	addq	$2, %rcx
	addq	$2, %rsi
	jmp	.L1tail
.L1cmp:
	movzbl	(%rsi), %eax
	cmpb	%al, (%rcx)
	setne	%al
	movzbl	%al, %eax
.Lret:
	ret
ENDPROC(__memcmp_avx)
EXPORT_SYMBOL(__memcmp_avx)
