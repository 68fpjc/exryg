*================================================================
*	key_init.s
*			Written by Igarashi
*================================================================
		.cpu	68000
*================================================================
__KEY_INIT	equ		$03
__EXIT		equ		$ff00
__FPUTS		equ		$ff1e
__EXIT2		equ		$ff4c
*================================================================
		.text
		.even
*================================================================
entry:
		tst.b	(a2)+
		bne	usage

		moveq.l	#0,d1
		moveq.l	#__KEY_INIT,d0
		trap	#15

		.dc.w	__EXIT

usage:
		move.w	#2,-(sp)	*STDERR
		pea.l	usgmes(pc)
		.dc.w	__FPUTS
		addq.l	#6,sp

		move.w	#1,-(sp)
		.dc.w	__EXIT2

usgmes:		.dc.b	'key_init.r 1997 Igarashi',$0d,$0a
		.dc.b	'IOCSコールKEY_INITを使用してキーボードを初期化します',$0d,$0a
		.dc.b	'usage:	key_init',$0d,$0a,0

*================================================================
		.end

