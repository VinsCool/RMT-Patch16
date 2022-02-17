;************************************************;
;* Simple RMT Player                            *;
;* For SAP and XEX music exports from RMT	*;
;* Recreation from disassembled code            *;
;* Original version by Raster/C.P.U., 2003-2004 *;
;* Recreation by VinsCool                       *;
;* Version 4, 14-02-2022                        *;
;************************************************;

;---------------------------------------------------------------------------------------------------------------------------------------------;

;* start of dasmplayer definitions...

; Export format, Atari Executable (XEX/OBX) or SAP

EXPORTXEX	equ 1
EXPORTSAP	equ 0

	ERT [EXPORTXEX+EXPORTSAP]=0	;* No format defined!
	ERT [EXPORTXEX+EXPORTSAP]=2	;* Only 1 format can be defined!

; starting line for songs when loaded, useful for playing from different lines or subtunes

STARTLINE	equ 0 

; playback speed will be adjusted accordingly in the other region

REGIONPLAYBACK	equ 1		; 0 => PAL
				; 1 => NTSC

; Stereo mode must be defined in 'rmt_feat.a65', in this case, this must be set to 1, otherwise, it will be defined here

STEREODEFINED	equ 0

	IFT !STEREODEFINED
STEREOMODE	equ 0
	EIF
				;* 0 => compile RMTplayer for 4 tracks mono
				;* 1 => compile RMTplayer for 8 tracks stereo
				;* 2 => compile RMTplayer for 4 tracks stereo L1 R2 R3 L4
				;* 3 => compile RMTplayer for 4 tracks stereo L1 L2 R3 R4
				;* 4 => compile RMTplayer for 8 tracks Dual Mono LR1 LR2 LR3 LR4

; screen line for synchronization, important to set with a good value to get smooth execution

VLINE		equ 7		; 16 is the default according to Raster's example player

; rasterbar colour

RASTERBAR	equ $69		; $69 is a nice purpleish hue

; some memory addresses

MODUL	equ $4000		; address of RMT module
DOSVEC	equ $000A
RTCLOK	equ $0012 		; Real Time Clock
VVBLKI	equ $0222		; Vertical Blank Immediate (VBI) Register
SDMCTL	equ $022F 		; Shadow Direct Memory Access Control address
SDLSTL	equ $0230
COLOR1	equ $02C5
COLOR2	equ $02C6
COLOR4	equ $02C8
CH	equ $02FC
PAL	equ $D014
COLPF2	equ $D018
COLBK	equ $D01A
KBCODE	equ $D209
SKSTAT	equ $D20F
VCOUNT	equ $D40B
WSYNC	equ $d40A 		; wait for hblank
NMIEN	equ $D40E

;* end of dasmplayer definitions...

;---------------------------------------------------------------------------------------------------------------------------------------------;

;* start of SAP format...

	IFT EXPORTSAP
	opt h- 
	icl 'sap.asm' 		; SAP plaintext data 
	opt h+ 

; assemble rmtplayr here... 

	icl 'rmtplayr.a65'	; execution address is $3400

; assemble SAP init here... used for region adjustment, seems exclusive to hardware(?) and Altirra emulator for now

	org $3E00		; same address used with Simple RMT Player because why not
	tax			; somehow the subtune is loaded in the accumulator at init
	lda subtune,x		; load a subtune based on the song line, indexed by x
	pha
region_init			; 50 Hz or 60 Hz?
	lda #0
	sta vcount		; reset the counter
	ldx #156		; default value for all regions
region_loop	
	lda vcount
	beq check_region	; vcount = 0, go to check_region and compare values
	tay			; backup the value in index y
	bne region_loop 	; repeat
check_region
	cpy #$9B		; compare index y to 155
	IFT REGIONPLAYBACK==0	; if the player region defined for PAL...
	bpl region_done		; negative result means the machine runs at 60hz
	ldx #131		; NTSC is detected, adjust the speed from PAL to NTSC (for some reason #130 skips a bit)
	ELI REGIONPLAYBACK==1	; else, if the player region defined for NTSC...
	bmi region_done		; positive result means the machine runs at 50hz
	ldx #187		; PAL is detected, adjust the speed from NTSC to PAL
	EIF			; endif
region_done
	stx $0490		; memory location used for screen synchronisation(?) in Altirra
	ldx #<MODUL		; low byte of RMT module to X reg
	ldy #>MODUL		; hi byte of RMT module to Y reg
	pla
	jsr rmt_init
	tay			; use the instrument speed as an offset
	lda tabpp-1,y		; load from the line counter spacing table
	sta $0406		; lines between each play(?) in Altirra
	rts
tabpp       
	dta 156,78,52,39	
subtune
;	dta $00,$0A,$20		; subtune line, can be as many as wanted, however, the SAP specs limit at 32
	EIF
	
;* end of SAP format...

;---------------------------------------------------------------------------------------------------------------------------------------------;

;* start of XEX format...

	IFT EXPORTXEX
	
; assemble rmtplayr here... 

	icl 'rmtplayr.a65'	; execution address is $3400

; assemble Simple RMT Player here... 
	
	org $3D00		; may become $3D00 instead of $3E00 due to the extra VBI checks going
start       
	ldx #0			; disable playfield and the black colour value
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	jsr wait_vblank		; wait for vblank before continuing
	stx COLOR4		; Shadow COLBK (background colour)
	stx COLOR2		; Shadow COLPF2 (playfield colour 2)
	ldx #$F			; white colour value
	stx COLOR1		; Shadow COLPF1 (Playfield colour 1), font colour
	mwa #dlist SDLSTL	; Start Address of the Display List
module_init	
	ldx #<MODUL		; low byte of RMT module to X reg
	ldy #>MODUL		; hi byte of RMT module to Y reg
	lda #STARTLINE		; starting song line 0-255 to A reg
	jsr rmt_init		; Init returns instrument speed (1..4 => from 1/screen to 4/screen)
	tay			; use the instrument speed as an offset
adjust_check
	cpy #5
	beq adjust_5vbi
	cpy #7
	beq adjust_7vbi
	cpy #8
	beq adjust_8vbi
	cpy #9
	beq adjust_9vbi
	cpy #10
	beq adjust_10vbi	
	cpy #11
	beq adjust_7vbi
	cpy #14
	beq adjust_7vbi
	cpy #15
	beq adjust_10vbi
	cpy #16
	beq adjust_9vbi
no_adjust
	bne do_speed_init_a
adjust_5vbi
	lda #155		; fixes 5xVBI
	bne do_speed_init
adjust_7vbi
	lda #154		; fixes 7xVBI, 11xVBI, 14xVBI
	bne do_speed_init
adjust_9vbi
	lda #153		; fixes 9xVBI, 16xVBI
	bne do_speed_init
adjust_8vbi
	lda #152		; fixes 8xVBI
	bne do_speed_init
adjust_10vbi
	lda #150		; fixes 10xVBI, 15xVBI
do_speed_init
	sta onefiftysix
do_speed_init_a
	lda tabpp-1,y		; load from the line counter spacing table
	sta acpapx2		; lines between each play
	ldx #$22		; DMA enable, normal playfield
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	ldx #100		; load into index x a 100 frames buffer
wait_init   
	jsr wait_vblank		; wait for vblank => 1 frame
	dex			; decrement index x
	bne wait_init		; repeat until x = 0, total wait time is ~2 seconds
region_init			; 50 Hz or 60 Hz?
	stx vcount		; x = 0, use it here
	ldx #156		; default value for all regions
onefiftysix equ *-1		; adjustments
region_loop	
	lda vcount
	beq check_region	; vcount = 0, go to check_region and compare values
	tay			; backup the value in index y
	bne region_loop 	; repeat
check_region
	cpy #$9B		; compare index y to 155
	IFT REGIONPLAYBACK==0	; if the player region defined for PAL...
	bpl region_done		; negative result means the machine runs at 60hz
	ldx #130		; NTSC is detected, adjust the speed from PAL to NTSC
	ELI REGIONPLAYBACK==1	; else, if the player region defined for NTSC...
	bmi region_done		; positive result means the machine runs at 50hz
	ldx #187		; PAL is detected, adjust the speed from NTSC to PAL
	EIF			; endif
region_done
	stx ppap		; value used for screen synchronisation
	sei			; Set Interrupt Disable Status
	mwa VVBLKI oldvbi       ; vbi address backup
	mwa #vbi VVBLKI		; write our own vbi address to it	
	mva #$40 NMIEN		; enable vbi interrupts
wait_sync
	lda VCOUNT		; current scanline 
	cmp #VLINE		; will stabilise the timing if equal
	bne wait_sync		; nope, repeat

; main loop, code runs from here after initialisation

loop
	ldy #RASTERBAR		; custom rasterbar colour
acpapx1
	lda spap
	ldx #0
cku	equ *-1
	bne keepup
	lda VCOUNT		; vertical line counter synchro
	tax
	sub #VLINE
lastpap	equ *-1
	scs:adc #$ff
ppap	equ *-1
	sta dpap
	stx lastpap
	lda #0
spap	equ *-1
	sub #0
dpap	equ *-1
	sta spap
	bcs acpapx1
keepup
	adc #$ff
acpapx2	equ *-1
	sta spap
	ldx #0
	scs:inx
	stx cku
play_loop
	sty WSYNC		; horizontal sync
	sty COLBK		; background colour
	sty COLPF2		; playfield colour 2
	jsr rmt_play		; setpokey + 1 play
	ldy #$00		; black colour value
	sty WSYNC		; horizontal sync
	sty COLBK		; background colour
	sty COLPF2		; playfield colour 2 
	beq loop                ; unconditional

; VBI loop

vbi
	sta WSYNC		; horizontal sync, so we're always on the exact same spot
	ldx <line_4		; line 4 of text
	lda SKSTAT		; Serial Port Status
	and #$08		; SHIFT key being held?
	bne set_line_4		; nope, skip the next ldx
	ldx <line_5		; line 5 of text (toggled by SHIFT)
set_line_4  
	stx txt_toggle		; write to change the text on line 4
	lda KBCODE		; Keyboard Code
	cmp #$1C		; ESCape key?
	bne continue		; nope => loop
stopmusic 
	jsr rmt_silence		; stop RMT and reset the POKEY registers
	mwa oldvbi VVBLKI	; restore the old vbi address
	ldx #$00		; disable playfield 
	stx SDMCTL		; write to Direct Memory Access (DMA) Control register
	dex			; underflow to #$FF
	stx CH			; write to the CH register, #$FF means no key pressed
	jsr wait_vblank		; wait for vblank before continuing
	jmp (DOSVEC)		; return to DOS, or Self Test by default
continue
	pla			; since we're in our own vbi routine, pulling all values manually is required
	tay
	pla
	tax
	pla
	sta WSYNC		; horizontal sync, this seems to make the timing more stable
	rti			; return from interrupt

; wait for vblank subroutine

wait_vblank 
	lda RTCLOK+2		; load the real time frame counter to accumulator
wait        
	cmp RTCLOK+2		; compare to itself
	beq wait		; equal means it vblank hasn't began
	rts
	
; Display list

dlist       
	:13 dta $70		; 8 blank lines, 13 times
	dta $42,a(line_1)	; ANTIC mode 2, memory address set to line_1
	dta $02,$02,$42		; Display ANTIC mode 2, 3 more times, displaying every other line in order
txt_toggle
	dta a(line_4)		; memory address set to line_4 by default, or line_5 when SHIFT is held
	dta $41,a(dlist)	; Jump and wait for vblank, return to dlist

; line counter spacing table for instrument speed from 1 to 16

tabpp       
	dta 156,78,52,39,31,26,22,19,17,15,14,13,12,11,10,9 

oldvbi	
	dta a(0)		; vbi address backup

; text strings, each line holds 40 characters, line 5 is toggled with the SHIFT key

	org $3F00		; must be at this memory address 

line_1	dta d"Line 1                                  "
line_2	dta d"Line 2                                  "
line_3	dta d"Line 3                                  "
line_4	dta d"Line 4 (hold SHIFT to toggle)           "
line_5	dta d"Line 5 (SHIFT is being held right now)  "

; set run address

	run start
	EIF 
	
;* end of XEX format...
	
;---------------------------------------------------------------------------------------------------------------------------------------------;

; insert actual .rmt module

	opt h-			; RMT module is standard Atari binary file already
	ins "music.rmt"		; include music RMT module

;---------------------------------------------------------------------------------------------------------------------------------------------;

; and that's all :D

