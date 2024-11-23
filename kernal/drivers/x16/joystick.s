;----------------------------------------------------------------------
; SNES Controller Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "banks.inc"
.include "io.inc"
.include "keycode.inc"
.include "regs.inc"

; KERNAL API
.export joystick_scan
.export joystick_get
; called by ps2 keyboard driver
.export joystick_from_ps2_init, joystick_from_ps2
.export joystick_ps2_keycodes

nes_data = d1pra
nes_ddr  = d1ddra

bit_latch = $04 ; PA2 LATCH (both controllers)
bit_jclk  = $08 ; PA3 CLK   (both controllers)
bit_data4 = $10 ; PA4 DATA  (controller #4)
bit_data3 = $20 ; PA5 DATA  (controller #3)
bit_data2 = $40 ; PA6 DATA  (controller #2)
bit_data1 = $80 ; PA7 DATA  (controller #1)

mintab0_len = 9
mintab1_len = 5
mintabs_len = mintab0_len+mintab1_len

.segment "KVARSB0"

j0tmp:	.res 1           ;    keyboard joystick temp
joy0:	.res 3           ;    keyboard joystick status
joy1:	.res 2           ;    joystick 1 status
joy2:	.res 2           ;    joystick 2 status
joy3:	.res 2           ;    joystick 3 status
joy4:	.res 2           ;    joystick 4 status
joycon: .res 1			 ;    joystick connected flags

; Keep these allocations adjacent for code in joystick_ps2_keycodes

mintabs:
mintab0:
	.res mintab0_len     ;    in-memory table for keycode -> joystick button (low controller bits)
mintab1:
	.res mintab1_len     ;    in-memory table for keycode -> joystick button (high controller bits)

.segment "JOYSTICK"

;---------------------------------------------------------------
; joystick_scan
;
; Function:  Scan all joysticks
;
;---------------------------------------------------------------
joystick_scan:
	KVARS_START_TRASH_A_NZ

	; Set latch and clock as outputs, and data1..4 as inputs, leave I2C pins (0..1) unchanged
	lda nes_ddr
	and #$ff-bit_data1-bit_data2-bit_data3-bit_data4
	ora #bit_latch+bit_jclk
	sta nes_ddr

	; Set latch=low and clock=high
	ldx #bit_jclk
	stx nes_data

	; Pulse latch for approx 12 us while clk=high
	lda #bit_latch+bit_jclk
	sta nes_data
	jsr wait_6us
	jsr wait_6us
	pha
	pla
	pha
	pla
	stx nes_data

	; Wait 6 us after latch falling edge
	jsr wait_6us
	nop
	
	; Read SNES controller bits 0..7
	ldy #8

l1:	; Drive NES clock low for approx 6 us and read data (SNES controller doesn't change when low)
	stz nes_data
	jsr wait_6us
	lda nes_data ; Read all controller bits
	stx nes_data ; Drive SNES clock high

	; Process while SNES clock is high for approx 6 us (bits change)
	rol        ; Move bit 7 into C
	rol joy1   ; Roll C into joy1
	rol        ; Move bit 6 into C
	rol joy2   ; Roll C into joy2
	rol        ; Roll bit 5 into C
	rol joy3   ; Roll C into joy3
	rol        ; Roll bit 4 into C
	rol joy4   ; Roll C into joy4
	nop
	nop
	nop

	dey
	bne l1

	; Read SNES controller bits 8..15
	ldy #8

l2:	; Drive SNES clock low for approx 6 us and read data (SNES controller doesn't change when low)
	stz nes_data
	jsr wait_6us
	lda nes_data ; Read all controller bits
	stx nes_data ; Drive SNES clock high

    ; Process while SNES clock is high for approx 6 us (bits change)
	rol        ; Move bit 7 into C
	rol joy1+1 ; Roll C into joy1
	rol        ; Move bit 6 into C
	rol joy2+1 ; Roll C into joy2
	rol        ; Roll bit 5 into C
	rol joy3+1 ; Roll C into joy3
	rol        ; Roll bit 4 into C
	rol joy4+1 ; Roll C into joy4
	nop
	nop
	nop

	dey
	bne l2

joy_detect:
	; Read one extra bit from SNES controller to detect if connected (0 = connected, 1 = not connected)
	stz nes_data ; Drive SNES clock low for approx 6 us (SNES controller doesn't change when low)
	jsr wait_6us
	lda nes_data ; Read all controller bits
	stx nes_data ; Drive SNES clock high

	; Store joytstick connection flags
	sta joycon

	KVARS_END_TRASH_A_NZ
	rts

wait_6us:
	pha
	pla
	pha
	pla
	nop
wait_3us:
	pha
	pla
	nop
	nop
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
	ldy #$ff
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
	bra @5

@0:
	lda joy0
	ldx joy0+1
	ldy joy0+2
	bra @5

@1:
	lda joycon
	and #bit_data1
	bne :+
	ldy #0
:	lda joy1
	ldx joy1+1
	bra @5

@2:
	lda joycon
	and #bit_data2
	bne :+
	ldy #0
:	lda joy2
	ldx joy2+1
	bra @5

@3:
	lda joycon
	and #bit_data3
	bne :+
	ldy #0
:	lda joy3
	ldx joy3+1
	bra @5

@4:
	lda joycon
	and #bit_data4
	bne :+
	ldy #0
:	lda joy4
	ldx joy4+1

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
	sta joy0+2 ; joy0 not present

	; populate the default keyboard joystick mapping

	ldx #intab0_len
:	lda intab0-1,x
	sta mintab0-1,x
	dex
	bne :-

	ldx #intab1_len
:	lda intab1-1,x
	sta mintab1-1,x
	dex
	bne :-

	rts

;----------------------------------------------------------------------
; joystick_ps2_keycodes:
;
; Get or set the keyboard mapping for joystick 0
; If carry is set, return the existing keycodes in r0-r6
; If carry is clear, set the keycodes from the values in r0-r6
;
;
; | r0L   | r0H  | r1L  | r1H | r2L   | r2H    | r3L | r3H | r4L |
; | Right | Left | Down | Up  | Start | Select | Y   | B   | B (alternate) |
;
; | r4H          | r5L          | r5H | r6L | r6H           |
; | R (shoulder) | L (shoulder) | X   | A   | A (alternate) |
;----------------------------------------------------------------------


joystick_ps2_keycodes:
	KVARS_START

	ldx #mintabs_len
	bcs @get
@set:
	lda r0-1,x
	sta mintabs-1,x
	dex
	bne @set
	bra @end
@get:
	lda mintabs-1,x
	sta r0-1,x
	dex
	bne @get
@end:

	KVARS_END
	rts

;----------------------------------------------------------------------
; joystick_from_ps2:
;
;  convert PS/2 keycode into SNES joystick state (internal)
;
; Note: This is called from the ps2kbd driver while bank 0 is active,
;       no bank switching is performed.
;
joystick_from_ps2:
	pha

	; Clear up/down bit
	and #$7f

	; Search key code table 0
	ldx #mintab0_len
:	cmp mintab0-1,x
	beq @match0
	dex
	bne :-

	; Search key code table 1
	ldx #mintab1_len
:	cmp mintab1-1,x
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
	.byte C_RT, C_LT, C_DN, C_UP
	.byte C_ST, C_SL, C_Y, C_B
	.byte C_B

outtab1:
	.byte C_R, C_L, C_X, C_A
	.byte C_A

intab0:
	.byte KEYCODE_RIGHTARROW, KEYCODE_LEFTARROW, KEYCODE_DOWNARROW, KEYCODE_UPARROW
	.byte KEYCODE_ENTER, KEYCODE_LSHIFT, KEYCODE_A, KEYCODE_Z
	.byte KEYCODE_LALT
intab0_len = *-intab0
.assert intab0_len = mintab0_len, error, "memory allocation for the PS/2 keycode lookup table mintab0 doesn't match the default table's length"

intab1:
	.byte KEYCODE_C, KEYCODE_D, KEYCODE_S, KEYCODE_X
	.byte KEYCODE_LCTRL
intab1_len = *-intab1
.assert intab1_len = mintab1_len, error, "memory allocation for the PS/2 keycode lookup table mintab1 doesn't match the default table's length"
