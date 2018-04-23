/* SPDX-License-Identifier: GPL-2.0 */
/* Copyright 2002 Andi Kleen, SuSE Labs */

#include <linux/linkage.h>
#include <asm/cpufeatures.h>
#include <asm/alternative-asm.h>
#include <asm/export.h>

.weak memset

/*
 * ISO C memset - set a memory block to a byte value. This function uses fast
 * string to get better performance than the original function. The code is
 * simpler and shorter than the original function as well.
 *
 * rdi   destination
 * rsi   value (char)
 * rdx   count (bytes)
 *
 * rax   original destination
 */
ENTRY(memset)
ENTRY(__memset)
	/*
	 * Some CPUs support enhanced REP MOVSB/STOSB feature. It is recommended
	 * to use it when possible. If not available, use fast string instructions.
	 *
	 * Otherwise, use original memset function.
	 */
	ALTERNATIVE_2 "jmp memset_orig", "", X86_FEATURE_REP_GOOD, \
		      "jmp memset_erms", X86_FEATURE_ERMS

	movq %rdi,%r9
	movq %rdx,%rcx
	andl $7,%edx
	shrq $3,%rcx
	/* expand byte value  */
	movzbl %sil,%esi
	movabs $0x0101010101010101,%rax
	imulq %rsi,%rax
	rep stosq
	movl %edx,%ecx
	rep stosb
	movq %r9,%rax
	ret
ENDPROC(memset)
ENDPROC(__memset)
EXPORT_SYMBOL(memset)
EXPORT_SYMBOL(__memset)

/*
 * ISO C memset - set a memory block to a byte value. This function uses
 * enhanced rep stosb to override the fast string function.
 * The code is simpler and shorter than the fast string function as well.
 *
 * rdi   destination
 * rsi   value (char)
 * rdx   count (bytes)
 *
 * rax   original destination
 */
ENTRY(memset_erms)
	movq %rdi,%r9
	movb %sil,%al
	movq %rdx,%rcx
	rep stosb
	movq %r9,%rax
	ret
ENDPROC(memset_erms)

ENTRY(memset_orig)
	movq %rdi,%r10

	/* expand byte value  */
	movzbl %sil,%ecx
	movabs $0x0101010101010101,%rax
	imulq  %rcx,%rax

	/* align dst */
	movl  %edi,%r9d
	andl  $7,%r9d
	jnz  .Lbad_alignment
.Lafter_bad_alignment:

	movq  %rdx,%rcx
	shrq  $6,%rcx
	jz	 .Lhandle_tail

	.p2align 4
.Lloop_64:
	decq  %rcx
	movq  %rax,(%rdi)
	movq  %rax,8(%rdi)
	movq  %rax,16(%rdi)
	movq  %rax,24(%rdi)
	movq  %rax,32(%rdi)
	movq  %rax,40(%rdi)
	movq  %rax,48(%rdi)
	movq  %rax,56(%rdi)
	leaq  64(%rdi),%rdi
	jnz    .Lloop_64

	/* Handle tail in loops. The loops should be faster than hard
	   to predict jump tables. */
	.p2align 4
.Lhandle_tail:
	movl	%edx,%ecx
	andl    $63&(~7),%ecx
	jz 		.Lhandle_7
	shrl	$3,%ecx
	.p2align 4
.Lloop_8:
	decl   %ecx
	movq  %rax,(%rdi)
	leaq  8(%rdi),%rdi
	jnz    .Lloop_8

.Lhandle_7:
	andl	$7,%edx
	jz      .Lende
	.p2align 4
.Lloop_1:
	decl    %edx
	movb 	%al,(%rdi)
	leaq	1(%rdi),%rdi
	jnz     .Lloop_1

.Lende:
	movq	%r10,%rax
	ret

.Lbad_alignment:
	cmpq $7,%rdx
	jbe	.Lhandle_7
	movq %rax,(%rdi)	/* unaligned store */
	movq $8,%r8
	subq %r9,%r8
	addq %r8,%rdi
	subq %r8,%rdx
	jmp .Lafter_bad_alignment
.Lfinal:
ENDPROC(memset_orig)

#ifdef CONFIG_SECURITY_TEMPESTA
ENTRY(__bzero_avx)
	movq	%rsi, %rax
	movq	%rdi, %rdx
	andq	$-128, %rax
	addq	%rdi, %rax
	cmpq	%rax, %rdi
	vpxor	%ymm0, %ymm0, %ymm0
	jb	.L128zer
	testb	$64, %sil
	jne	.L64zer
.L32tail:
	testb	$32, %sil
	jne	.L32zer
.L16tail:
	movq	%rdx, %rax
	testb	$16, %sil
	jne	.L16zer
.L8tail:
	testb	$8, %sil
	jne	.L8zer
.L4tail:
	testb	$4, %sil
	jne	.L4zer
.L2tail:
	testb	$2, %sil
	jne	.L2zer
.L1tail:
	andl	$1, %esi
	jne	.L1zer
	/* Don't clean the registers w/ vzeroupper. */
	ret
	.p2align 4
.L128zer:
	vmovdqu	%ymm0, (%rdx)
	subq	$-128, %rdx
	vmovdqu	%ymm0, -96(%rdx)
	vmovdqu	%ymm0, -64(%rdx)
	vmovdqu	%ymm0, -32(%rdx)
	cmpq	%rdx, %rax
	ja	.L128zer
	movq	%rdi, %rdx
	notq	%rdx
	addq	%rdx, %rax
	andq	$-128, %rax
	leaq	128(%rdi,%rax), %rdx
	testb	$64, %sil
	je	.L32tail
.L64zer:
	addq	$64, %rdx
	vmovdqu	%ymm0, -64(%rdx)
	vmovdqu	%ymm0, -32(%rdx)
	testb	$32, %sil
	je	.L16tail
.L32zer:
	addq	$32, %rdx
	vmovdqu	%ymm0, -32(%rdx)
	movq	%rdx, %rax
	testb	$16, %sil
	je	.L8tail
.L16zer:
	addq	$16, %rax
	vmovups	%xmm0, (%rdx)
	testb	$8, %sil
	je	.L4tail
.L8zer:
	movq	$0, (%rax)
	addq	$8, %rax
	testb	$4, %sil
	je	.L2tail
.L4zer:
	movl	$0, (%rax)
	addq	$4, %rax
	testb	$2, %sil
	je	.L1tail
.L2zer:
	movw	$0, (%rax)
	addq	$2, %rax
	andl	$1, %esi
	je	.Lret
.L1zer:
	movb	$0, (%rax)
.Lret:
	ret
ENDPROC(__bzero_avx)
EXPORT_SYMBOL(__bzero_avx)
#endif
