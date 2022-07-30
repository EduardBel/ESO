	.arch armv5te
	.eabi_attribute 23, 1
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 1
	.eabi_attribute 30, 6
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"SUPI.c"
	.section	.rodata
	.align	2
.LC0:
	.ascii	"-- Programa PI  -  PID (%d) --\012\000"
	.align	2
.LC1:
	.ascii	"%2 Iteracio: %d: \012\000"
	.align	2
.LC2:
	.ascii	"%2 PI: %d,%d \012\012\000"
	.text
	.align	2
	.global	_start
	.syntax unified
	.arm
	.fpu softvfp
	.type	_start, %function
_start:
	@ args = 0, pretend = 0, frame = 40
	@ frame_needed = 0, uses_anonymous_args = 0
	str	lr, [sp, #-4]!
	sub	sp, sp, #44
	str	r0, [sp, #4]
	mov	r3, #1
	str	r3, [sp, #36]
	mov	r3, #0
	str	r3, [sp, #32]
	ldr	r3, .L9
	str	r3, [sp, #24]
	ldr	r3, [sp, #24]
	lsl	r3, r3, #2
	str	r3, [sp, #20]
	mov	r3, #1
	str	r3, [sp, #28]
	ldr	r3, [sp, #4]
	cmp	r3, #0
	bge	.L2
	mov	r3, #0
	str	r3, [sp, #4]
	b	.L3
.L2:
	ldr	r3, [sp, #4]
	cmp	r3, #3
	ble	.L3
	mov	r3, #3
	str	r3, [sp, #4]
.L3:
	bl	GARLIC_clear
	bl	GARLIC_pid
	mov	r3, r0
	mov	r1, r3
	ldr	r0, .L9+4
	bl	GARLIC_printf
	ldr	r3, [sp, #4]
	add	r3, r3, #1
	str	r3, [sp, #4]
	ldr	r2, [sp, #4]
	mov	r3, r2
	lsl	r3, r3, #2
	add	r3, r3, r2
	lsl	r3, r3, #1
	str	r3, [sp, #4]
	b	.L4
.L7:
	ldr	r0, [sp, #20]
	ldr	r1, [sp, #36]
	add	r3, sp, #12
	add	r2, sp, #16
	bl	GARLIC_divmod
	ldr	r3, [sp, #28]
	and	r3, r3, #1
	cmp	r3, #0
	bne	.L5
	ldr	r2, [sp, #32]
	ldr	r3, [sp, #16]
	sub	r3, r2, r3
	str	r3, [sp, #32]
	b	.L6
.L5:
	ldr	r2, [sp, #32]
	ldr	r3, [sp, #16]
	add	r3, r2, r3
	str	r3, [sp, #32]
.L6:
	ldr	r0, [sp, #32]
	ldr	r1, [sp, #24]
	add	r3, sp, #12
	add	r2, sp, #16
	bl	GARLIC_divmod
	ldr	r1, [sp, #28]
	ldr	r0, .L9+8
	bl	GARLIC_printf
	ldr	r3, [sp, #16]
	ldr	r2, [sp, #12]
	mov	r1, r3
	ldr	r0, .L9+12
	bl	GARLIC_printf
	ldr	r3, [sp, #36]
	add	r3, r3, #2
	str	r3, [sp, #36]
	ldr	r3, [sp, #28]
	add	r3, r3, #1
	str	r3, [sp, #28]
.L4:
	ldr	r2, [sp, #28]
	ldr	r3, [sp, #4]
	cmp	r2, r3
	ble	.L7
	mov	r3, #0
	mov	r0, r3
	add	sp, sp, #44
	@ sp needed
	ldr	pc, [sp], #4
.L10:
	.align	2
.L9:
	.word	100000
	.word	.LC0
	.word	.LC1
	.word	.LC2
	.size	_start, .-_start
	.ident	"GCC: (devkitARM release 46) 6.3.0"
