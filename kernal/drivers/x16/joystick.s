;----------------------------------------------------------------------
; SNES Controller Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "banks.inc"
.include "io.inc"

; KERNAL API
.export joystick_scan
.export joystick_get
; called by ps2 keyboard driver
.export joystick_from_ps2_init, joystick_from_ps2

nes_data = d1pra
nes_ddr  = d1ddra

bit_latch = $04 ; PA2 LATCH (both controllers)
bit_jclk  = $08 ; PA3 CLK   (both controllers)
bit_data4 = $10 ; PA4 DATA  (controller #4)
bit_data3 = $20 ; PA5 DATA  (controller #3)
bit_data2 = $40 ; PA6 DATA  (controller #2)
bit_data1 = $80 ; PA7 DATA  (controller #1)

.segment "KVARSB0"

j0tmp:	.res 1           ;    keyboard joystick temp
joy0:	.res 3           ;    keyboard joystick status
joy1:	.res 3           ;    joystick 1 status
joy2:	.res 3           ;    joystick 2 status
joy3:	.res 3           ;    joystick 3 status
joy4:	.res 3           ;    joystick 4 status

.segment "JOYSTICK"

;---------------------------------------------------------------
; joystick_scan
;
; Function:  Scan all joysticks
;
;---------------------------------------------------------------
joystick_scan:
	KVARS_START_TRASH_A_NZ

	lda nes_ddr
	and #$ff-bit_data1-bit_data2-bit_data3-bit_data4
	ora #bit_latch+bit_jclk
	sta nes_ddr
	lda #bit_latch+bit_jclk
	trb nes_data

	; pulse latch
	lda #bit_latch
	tsb nes_data
	trb nes_data

	; read 3x 8 bits
	ldx #0
l2:	ldy #8
l1:	lda nes_data
	rol
	rol joy1,x ;If top bit was set, carry will be set rotate that into joy1
	rol
	rol joy2,x ;rol into joy2
	rol
	rol joy3,x
	rol
	rol joy4,x

	lda #bit_jclk
	tsb nes_data
	trb nes_data
	dey
	bne l1
	inx
	cpx #3
	bne l2

	; force present if controller ID (bits 8-11) is not 15
	; ldy #0
	lda joy1+1
	and #%00001111
	cmp #15
	bne :+
	sty joy1+2
:	lda joy2+1
	and #%00001111
	cmp #15
	bne :+
	sty joy2+2
:	lda joy3+1
	and #%00001111
	cmp #15
	bne :+
	sty joy3+2
:	lda joy4+1
	and #%00001111
	cmp #15
	bne :+
	sty joy4+2
:

	KVARS_END_TRASH_A_NZ
	rts

;---------------------------------------------------------------
; joystick_get
;
; Function:  Return the state of a given joystick.
;
; Pass:      a    number of joystick (0-3)
; Return:    a    byte 0:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;                         SNES | B | Y |SEL|STA|UP |DN |LT |RT |
;
;            x    byte 1:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;                         SNES | A | X | L | R | 1 | 1 | 1 | 1 |
;            y    byte 2:
;                         $00 = joystick present
;                         $FF = joystick not present
;
; Note:      * Presence can be detected by checking byte 2.
;---------------------------------------------------------------
joystick_get:
	KVARS_START_TRASH_X_NZ
	tax
	beq @0       ; -> joy0
	dex
	beq @1       ; -> joy1
	dex
	beq @2       ; -> joy2
	dex
	beq @3       ; -> joy3
	dex
	beq @4       ; -> joy4
	lda #$ff
	tax
	tay
	bra @5

@0:
	lda joy0
	ldx joy0+1
	ldy joy0+2
	bra @5

@1:
	lda joy1
	ldx joy1+1
	ldy joy1+2
	bra @5

@2:
	lda joy2
	ldx joy2+1
	ldy joy2+2
	bra @5

@3:
	lda joy3
	ldx joy3+1
	ldy joy3+2
	bra @5

@4:
	lda joy4
	ldx joy4+1
	ldy joy4+2

@5:	KVARS_END
	rts

;----------------------------------------------------------------------
; joystick_from_ps2:
;
;  init keyboard joystick state (internal)
;
; Note: This is called from the ps2kbd driver while bank 0 is active,
;       no bank switching is performed.
;
joystick_from_ps2_init:
	lda #$ff
	sta joy0
	sta joy0+1
	sta joy0+2 ; joy0 bot present
	rts

;----------------------------------------------------------------------
; joystick_from_ps2:
;
;  convert PS/2 scancode into SNES joystick state (internal)
;
; Note: This is called from the ps2kbd driver while bank 0 is active,
;       no bank switching is performed.
;
joystick_from_ps2:
	pha

	; Clear up/down bit
	and #$7f
	
	; Search key code table 0
	ldx #8
:	cmp intab0-1,x
	beq @match0
	dex
	bne :-

	; Search key code table 1
	ldx #4
:	cmp intab1-1,x
	beq @match1
	dex
	bne :-

	; Exit
@end:	stz joy0+2
	pla
	rts

@match0:
	pla
	pha
	bmi :+		; key up

	lda outtab0-1,x
	eor #$ff
	and joy0
	sta joy0
	bra @end

:	lda outtab0-1,x
	ora joy0
	sta joy0
	bra @end

@match1:
	pla
	pha
	bmi :+		; key up

	lda outtab1-1,x
	eor #$ff
	and joy0+1
	sta joy0+1
	bra @end

:	lda outtab1-1,x
	ora joy0+1
	sta joy0+1
	bra @end


C_RT = 1
C_LT = 2
C_DN = 4
C_UP = 8
C_ST = 16
C_SL = 32
C_Y  = 64
C_B  = 128

C_R  = 16
C_L  = 32
C_X  = 64
C_A  = 128

;     SNES |   A   |   B  | X | Y | L | R | START  | SELECT |
; keyboard |   X   |   Z  | S | A | D | C | RETURN | LShift |
;          | LCtrl | LAlt |

outtab0:
	.byte C_RT, C_LT, C_DN, C_UP, C_ST, C_SL, C_Y, C_B
outtab1:
	.byte C_R, C_L, C_X, C_A

intab0:	.byte 89, 79, 84, 83, 43, 44, 30, 46
intab1:	.byte 48, 33, 32, 47
