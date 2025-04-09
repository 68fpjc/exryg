*================================================================
*	exryg.s
*			Written by Igarashi
*================================================================
		.cpu	68000
*================================================================
		.include	doscall.mac
		.include	iocscall.mac
*================================================================
		.offset	0
verFDATE:	.ds.l	1
verFLEN:	.ds.l	1
verOFFSET:	.ds.l	1
verREADLEN:	.ds.l	1
verPATCH0:	.ds.l	1
verPATCH1:	.ds.l	1
SIZEofVERTBL:
		.text

VERTBL		.macro	fdate,flen,offset,readlen,patchpos0,patchpos1
		.dc.l	fdate,flen,offset+$40,readlen,patchpos0-offset,patchpos1-offset
		.endm

*================================================================
		.text
		.even
*================================================================
entry:
		bsr	memoff
		bsr	chkarg
		bsr	main
		bsr	memfree
		DOS	__EXIT

errorexit:
		bsr	memfree
		move.w	#1,-(sp)
		DOS	__EXIT2

*================================================================
memoff:
		lea.l	16(a0),a0
		suba.l	a0,a1
		pea.l	(a1)
		pea.l	(a0)
		DOS	__SETBLOCK
		addq.l	#8,sp
		rts

*================================================================
memfree:			*メモリブロック解放
		move.l	bootxmem,d0
		bsr	8f
		move.l	sourmem,d0
		bsr	8f
		move.l	destmem,d0
8:		beq	@f
		move.l	d0,-(sp)
		DOS	__MFREE
		addq.l	#4,sp
@@:		rts

*================================================================
main:				*メイン
		bsr	makesourfn
		bsr	makedestfn

		bsr	readbootx

		bsr	putsourmes
		bsr	readsourfile

		bsr	putdestmes
		bsr	expand

		bsr	putcompletemes
 .ifdef CHKX
		bsr	chkxfile
		bne	@f
		bsr	putxfilemes
 .endif
@@:		bsr	putcrlf

		rts

*================================================================
getfileinfo:
		move.w	#$0020,-(sp)	*ARCHIVE
		pea.l	(a0)
		pea.l	filesbuf(pc)
		DOS	__FILES
		lea.l	10(sp),sp
		tst.l	d0
		rts

*================================================================
makesourfn:
		lea.l	sourfnbuf(pc),a1
@@:		tst.b	(a1)+
		bne	@b
		subq.l	#1,a1
		lea.l	sourfnbuf+$43(pc),a0	*namNAME
@@:		move.b	(a0)+,(a1)+
		bne	@b
		subq.l	#1,a1
		lea.l	sourfnbuf+$56(pc),a0	*namEXT
@@:		move.b	(a0)+,(a1)+
		bne	@b
		rts

*================================================================
makedestfn:
		lea.l	destfnbuf(pc),a1
		lea.l	sourfnbuf+$43(pc),a0	*namNAME
@@:		move.b	(a0)+,(a1)+
		bne	@b
		subq.l	#1,a1
		lea.l	destext(pc),a0
@@:		move.b	(a0)+,(a1)+
		bne	@b
		rts

*================================================================
readsourfile:
		lea.l	sourfnbuf(pc),a0
		bsr	getfileinfo
		bmi	nfoundsour

		move.l	filesbuf+$1a,d1	*FLEN

		move.l	d1,-(sp)
		DOS	__MALLOC
*		addq.l	#4,sp
		tst.l	d0
		bmi	nomemory
		move.l	d0,sourmem
		movea.l	d0,a0

		clr.w	-(sp)		*WOPEN
		pea.l	sourfnbuf(pc)
		DOS	__OPEN
*		addq.l	#6,sp
		move.l	d0,d2
		bmi	cantopensour

		move.l	d1,-(sp)
		pea.l	(a0)
		move.w	d2,-(sp)
		DOS	__READ
*		lea.l	10(sp),sp

		move.w	d2,-(sp)
		DOS	__CLOSE
*		addq.l	#2,sp
		lea.l	4+6+10+2(sp),sp

		subq.l	#5,d1
		cmp.l	(a0),d1
		bne	illformat

		rts

*================================================================
readbootx:			*BOOT.X の読み込み
		lea.l	bootxfn(pc),a0
		bsr	getfileinfo
		bmi	nfoundbootx

				*バージョンチェック
		lea.l	vertbl(pc),a0
		bra	2f
1:		lea.l	SIZEofVERTBL(a0),a0
2:		move.l	verFDATE(a0),d0
		beq	illversion
		cmp.l	filesbuf+$16(pc),d0	*FTIME
		bne	1b
		move.l	verFLEN(a0),d0
		cmp.l	filesbuf+$1a(pc),d0	*FLEN
		bne	1b

				*読み込み
		move.l	verREADLEN(a0),-(sp)
		DOS	__MALLOC
*		addq.l	#4,sp
		tst.l	d0
		bmi	nomemory
		move.l	d0,bootxmem
		movea.l	d0,a1

		clr.w	-(sp)		*WOPEN
		pea.l	bootxfn(pc)
		DOS	__OPEN
*		addq.l	#6,sp
		move.l	d0,d1
		bmi	cantopenbootx

		clr.w	-(sp)		*SEEK_SET
		move.l	verOFFSET(a0),-(sp)
		move.w	d1,-(sp)
		DOS	__SEEK
*		addq.l	#8,sp

		move.l	verREADLEN(a0),-(sp)
		pea.l	(a1)
		move.w	d1,-(sp)
		DOS	__READ
*		lea.l	10(sp),sp

		move.w	d1,-(sp)
		DOS	__CLOSE
*		addq.l	#2,sp
		lea.l	4+6+8+10+2(sp),sp

				*読み込んだプログラムにパッチを当てる
 .if 0
		move.l	verPATCH0(a0),d0
		lea.l	0(a1,d0.l),a2	*a2 = パッチ位置
		lea.l	patch0(pc),a3	*copy 3 word
		move.l	(a2),(a3)+	*
		move.w	4(a2),(a3)	*}
		move.w	patch0_,(a2)+	*jmp.l
		move.l	#patch0,(a2)+	*abs addr
		move.l	a2,patch0_+2	*abs addr
 .endif
		move.l	verPATCH1(a0),d0
		lea.l	0(a1,d0.l),a2	*a2 = パッチ位置
		lea.l	patch1(pc),a3	*copy 3 word
		move.l	(a2),(a3)+	*
		move.w	4(a2),(a3)	*}
		move.w	patch1_,(a2)+	*jmp.l
		move.l	#patch1,(a2)+	*abs addr
		move.l	a2,patch1_+2	*abs addr

				*キャッシュフラッシュ
		lea.l	$cbc.w,a1
		IOCS	__B_BPEEK
		tst.b	d0
		beq	@f
		moveq.l	#3,d1		*flush
		moveq.l	#$ac,d0		*SYS_STAT
		trap	#15
@@:
		rts

patch0:		.ds.w	3
patch0_:	jmp	0.l	*2+4

patch1:		.ds.w	3
		move.l	d0,destflen
patch1_:	jmp	0.l	*2+4

*================================================================
expand:
		move.l	#$00ffffff,d1
		move.l	d1,-(sp)
		DOS	__MALLOC
*		addq.l	#4,sp
		and.l	d1,d0
		move.l	d0,-(sp)
		DOS	__MALLOC
*		addq.l	#4,sp
		tst.l	d0
		bmi	nomemory
		move.l	d0,destmem

		movea.l	d0,a0
		movea.l	sourmem(pc),a1
		movea.l	bootxmem(pc),a2
		jsr	(a2)

		move.w	#$0020,-(sp)	*ARCHIVE
		pea.l	destfnbuf(pc)
		DOS	__CREATE
*		addq.l	#6,sp
		move.l	d0,d1
		bmi	cantopendest

		move.l	destflen(pc),-(sp)
		move.l	destmem(pc),-(sp)
		move.w	d1,-(sp)
		DOS	__WRITE
*		lea.l	10(sp),sp

		move.w	d1,-(sp)
		DOS	__CLOSE
*		addq.l	#2,sp
		lea.l	4+4+6+10+2(sp),sp

		rts

*================================================================
 .ifdef CHKX
chkxfile:			*いいかげんな *.x フォーマットチェック
		movea.l	destmem(pc),a0
		cmpi.w	#'HU',(a0)
		rts
 .endif

*================================================================
chkarg:				*コマンドライン解析
		addq.l	#1,a2

1:		move.b	(a2)+,d0
		beq	9f
		cmpi.b	#' ',d0
		beq	1b
		cmpi.b	#'	',d0
		beq	1b

		cmpi.b	#'-',d0
		beq	usage

		pea.l	sourfnbuf(pc)
		pea.l	-1(a2)
		DOS	__NAMECK
		addq.l	#8,sp
		tst.l	d0
		bmi	illfname
		tst.b	d0
		bne	illfname
5:		move.b	(a2)+,d0
		beq	9f
		cmpi.b	#' ',d0
		beq	1b
		cmpi.b	#'	',d0
		bne	5b
		bra	1b

9:		tst.b	sourfnbuf+$00	*namDRIVE
		beq	usage
		rts

*================================================================
putcompletemes:
		lea.l	completemes(pc),a0
		bra	putmes
putsourmes:
		lea.l	sourmes(pc),a0
		bsr	putmes
		lea.l	sourfnbuf(pc),a0
		bsr	putmes
		bra	putcrlf
putdestmes:
		lea.l	destmes(pc),a0
		bsr	putmes
		lea.l	destfnbuf(pc),a0
		bsr	putmes
		bra	putcrlf
 .ifdef CHKX
putxfilemes:
		lea.l	xfilemes(pc),a0
		bra	putmes
 .endif
putcrlf:
		lea.l	crlfmes(pc),a0
putmes:
		pea.l	(a0)
		DOS	__PRINT
		addq.l	#4,sp
		rts

*================================================================
nfoundbootx:
		lea.l	bootxfn(pc),a0
		bsr	puterrmes
		lea.l	nfoundmes(pc),a0
		bsr	puterrmes
		bra	errorexit
nfoundsour:
		lea.l	sourfnbuf(pc),a0
		bsr	puterrmes
		lea.l	nfoundmes(pc),a0
		bsr	puterrmes
		bra	errorexit
nomemory:
		lea.l	nomemmes(pc),a0
		bsr	puterrmes
		bra	errorexit
illfname:
		lea.l	illfnmes(pc),a0
		bsr	puterrmes
		bra	errorexit
illformat:
		lea.l	illfmtmes(pc),a0
		bsr	puterrmes
		bra	errorexit
illversion:
		lea.l	illvermes(pc),a0
		bsr	puterrmes
		bra	errorexit
cantopensour:
		lea.l	sourfnbuf(pc),a0
		bra	cantopen
cantopendest:
		lea.l	destfnbuf(pc),a0
		bra	cantopen
cantopenbootx:
		lea.l	bootxfn(pc),a0
cantopen:
		bsr	puterrmes
		lea.l	cantopenmes(pc),a0
		bsr	puterrmes
		bra	errorexit
usage:
		lea.l	usgmes(pc),a0
		bsr	puterrmes
		bra	errorexit
puterrmes:
		move.w	#2,-(sp)	*STDERR
		pea.l	(a0)
		DOS	__FPUTS
		addq.l	#6,sp
		rts

*================================================================
vertbl:		VERTBL	$BB8D1C8C,$0000B35A,$012a2,$001376-$0012a2,$0012a2,$00134c+2
		.dc.l	0

usgmes:		.dc.b	'アルゴスの戦士 RYG file decomplessor '
		.dc.b	'Copyright 1998 Igarashi',$0d,$0a
		.dc.b	'usage:	exryg <filename.ext>'
crlfmes:	.dc.b	$0d,$0a,0
sourmes:	.dc.b	'入力ファイル ... ',0
destmes:	.dc.b	'出力ファイル ... ',0
completemes:	.dc.b	'終了しました.',0
 .ifdef CHKX
xfilemes:	.dc.b	' 出力ファイルは *.x ファイルと思われます.',0
 .endif
nomemmes:	.dc.b	'メモリ不足です.',$0d,$0a,0
illfnmes:	.dc.b	'不正なファイル名です.'
illfmtmes:	.dc.b	'ファイルフォーマットが異常です.',$0d,$0a,0
nfoundmes:	.dc.b	' が見つかりません.',$0d,$0a,0
cantopenmes:	.dc.b	' がオープンできません.',$0d,$0a,0
illvermes:	.dc.b	'BOOT.X のバージョンが違います.',$0d,$0a,0

destext:	.dc.b	'.bin',0
bootxfn:	.dc.b	'BOOT.X',0

*================================================================
		.bss
		.even
*================================================================
bootxmem:	.ds.l	1	*メモリブロックアドレス (BOOT.X)
sourmem:	.ds.l	1	*メモリブロックアドレス (入力ファイル)
destmem:	.ds.l	1	*メモリブロックアドレス (出力ファイル)
destmemend:	.ds.l	1	*destmem の終端アドレス
destflen:	.ds.l	1	*出力ファイルのサイズ
filesbuf:	.ds.b	53+1	*SIZEofFILESBUF
sourfnbuf:	.ds.b	91+1	*SIZEofNAMECKBUF
destfnbuf:	.ds.b	18+1+3+1

*================================================================
		.end	entry

