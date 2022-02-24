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

;VLINE		equ 7		; 16 is the default according to Raster's example player

; The target is to get the first rmtplay occuring on scanline 16 (NTSC) or ?? (PAL) for stability
; VLINE cannot be higher than 155! Otherwise, it will never work, and stay in an endless loop!
;
; NTSC 	->	VLINE must be: 	7 for 1x, 85 for 2x,
; PAL 	->	VLINE must be:	??
;
; NTSC2PAL ->	VLINE must be:	7 for 1x, 7 for 2x,
; PAL2NTSC ->	VLINE must be:	??

VLINE		equ 7		; nice round numbers fit well with multiples of 8 for every xVBI...

	ERT VLINE>155		; VLINE cannot be higher than 155!

; rasterbar colour

RASTERBAR	equ $69		; $69 is a nice purpleish hue

; VU Meter decay rate and speed

RATE		equ 1		; set the amount of volume decay is done, 0 is no decay, 15 is instant
SPEED		equ 1		; set the speed of decay rate, 0 is no decay, 255 is the highest amount of delay (in frames) 

; some memory addresses

DISPLAY equ $FE			; zeropage address of the Display List indirect memory address

MODUL	equ $4000		; address of RMT module
DOSVEC	equ $000A
RTCLOK	equ $0012 		; Real Time Clock
VVBLKI	equ $0222		; Vertical Blank Immediate (VBI) Register
SDMCTL	equ $022F 		; Shadow Direct Memory Access Control address
SDLSTL	equ $0230
COLOR0	equ $02C4
COLOR1	equ $02C5
COLOR2	equ $02C6
COLOR3	equ $02C7
COLOR4	equ $02C8
CH1	equ $02F2
CH	equ $02FC
PAL	equ $D014
COLPF0	equ $D016
COLPF1	equ $D017
COLPF2	equ $D018
COLPF3	equ $D019
COLBK	equ $D01A
KBCODE	equ $D209
SKSTAT	equ $D20F
VCOUNT	equ $D40B
rCHBASE equ $d409 		; character gfx address
WSYNC	equ $d40A 		; wait for hblank
NMIEN	equ $D40E

FONT    equ $bc00       	; custom font location

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
	
;-----------------

; assemble Simple RMT Player here... 
	
	org $3B00		; at some point this will no longer fit...
start       
	ldx #0			; disable playfield and the black colour value
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	jsr wait_vblank		; wait for vblank before continuing
	stx COLOR4		; Shadow COLBK (background colour), black
	stx COLOR2		; Shadow COLPF2 (playfield colour 2), black
	mwa #dlist SDLSTL	; Start Address of the Display List
	mva #>FONT rCHBASE      ; load the font address into the character register, same things apply to it
	mwa #line_0 DISPLAY	; initialise the Display List indirect memory address for later

set_colours
	lda #74
	sta COLOR3
	lda #223
	sta COLOR1
	lda #30
	sta COLOR0
	
;-----------------
		
module_init	
	ldx #<MODUL		; low byte of RMT module to X reg
	ldy #>MODUL		; hi byte of RMT module to Y reg
	lda #STARTLINE		; starting song line 0-255 to A reg
	jsr rmt_init		; Init returns instrument speed (1..4 => from 1/screen to 4/screen)
	tay			; use the instrument speed as an offset
	
;-----------------
	
adjust_check
	beq adjust_check_a	; Y is 0 if equal, this is invalid!
	bpl adjust_check_b	; Y = 1 to 127, however, 16 is the maximum supported
adjust_check_a
	ldy #1			; if Y is 0, nagative, or above 16, this will be bypassed!
	sty v_instrspeed	; failsafe, instrument speed of 1 is forced
	sty v_ainstrspeed 	; both values need to be overwritten for the fix to work correctly
adjust_check_b
	cpy #17			; Y = 17?
	bcs adjust_check_a	; everything equal or above 17 is invalid! 
adjust_check_c
	sty instrspeed		; print later ;)
	cpy #5
	bcc do_speed_init	; all values between 1 to 4 don't need adjustments
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
adjust_9vbi			; 16 is the maximal number supported, and uses the 9xVBI fix
	lda #153		; fixes 9xVBI, 16xVBI
	bne do_vbi_fix
adjust_5vbi
	lda #155		; fixes 5xVBI
	bne do_vbi_fix
adjust_7vbi
	lda #154		; fixes 7xVBI, 11xVBI, 14xVBI
	bne do_vbi_fix
adjust_8vbi
	lda #152		; fixes 8xVBI
	bne do_vbi_fix
adjust_10vbi
	lda #150		; fixes 10xVBI, 15xVBI
do_vbi_fix
	sta onefiftysix
	
;-----------------
	
do_speed_init
	lda tabpp-1,y		; load from the line counter spacing table
	sta acpapx2		; lines between each play
	ldx #$22		; DMA enable, normal playfield
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	ldx #100		; load into index x a 100 frames buffer
wait_init   
	jsr wait_vblank		; wait for vblank => 1 frame
	
	mva #>FONT rCHBASE	
	
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
	
;-----------------
	
check_region
	cpy #$9B		; compare index y to 155
	IFT REGIONPLAYBACK==0	; if the player region defined for PAL...
	bpl region_done		; negative result means the machine runs at 60hz
	ldx #130		; NTSC is detected, adjust the speed from PAL to NTSC
	
	ELI REGIONPLAYBACK==1	; else, if the player region defined for NTSC...
	bmi region_done		; positive result means the machine runs at 50hz

	ldx #186		; PAL is detected, adjust the speed from NTSC to PAL
	lda instrspeed		; what value did RMT return again?
	cmp #1
	beq subonetotiming	; 1xVBI is stable if 1 is subtracted from the value, 186 must be used!
	cmp #2
	beq subfourtotiming	; 2xVBI is stable if 4 is subtracted from the value, 185 must be used!
	cmp #3
	beq region_done		; 3xVBI is stable without a subtraction
	cmp #4
	beq subtwototiming	; 4xVBI is stable if 2 is subtracted from the value, 185 must be used!

subfourtotiming
;	ldx #185
	dec acpapx2		; stabilise NTSC timing in PAL mode

subthreetotiming
	dec acpapx2		; stabilise NTSC timing in PAL mode
	
subtwototiming
	ldx #185
	dec acpapx2		; stabilise NTSC timing in PAL mode	
subonetotiming
	dec acpapx2		; stabilise NTSC timing in PAL mode
	
	EIF			; endif
	
region_done
	sty region_byte		; set region flag to print later
	stx ppap		; value used for screen synchronisation
	sei			; Set Interrupt Disable Status
	mwa VVBLKI oldvbi       ; vbi address backup
	mwa #vbi VVBLKI		; write our own vbi address to it	
	mva #$40 NMIEN		; enable vbi interrupts
	
	mva #>FONT rCHBASE
	
;-----------------

; print instrument speed, done once per initialisation

	ldy #4			; 4 characters buffer 
	lda #0
instrspeed 	equ *-1
	jsr printhex_direct
	lda #0
	dey			; Y = 4 here, no need to reload it
	sta (DISPLAY),y 
	mva:rne txt_VBI-1,y line_0+5,y-
	
	lda MODUL+3		; RMT4 or RMT8?
	cmp #$34
	beq is_rmt4		; RMT4 if equal, nothing to do
	
is_rmt8
	ldy #8			; 8 characters buffer
	mva:rne txt_VBI+4,y line_0+10,y-
is_rmt4
	
;-----------------
	
; print region, done once per initialisation

	ldy #4			; 4 characters buffer 
	lda #0
region_byte	equ *-1
	cmp #$9B
	bmi is_NTSC
is_PAL
	ldx #50
	mva:rne txt_PAL-1,y line_0-1,y-
	beq is_DONE
is_NTSC
	ldx #60
	mva:rne txt_NTSC-1,y line_0-1,y-
is_DONE				
	sty v_second		; Y is 0, reset the timer with it
	sty v_minute
	stx v_frame		; X is either 50 or 60, defined by the region initialisation
	stx framecount

;------------------
	
wait_sync
	lda VCOUNT		; current scanline 
	cmp #VLINE		; will stabilise the timing if equal
	bcc wait_sync		; nope, repeat

;-----------------

; main loop, code runs from here ad infinitum after initialisation

loop
	ldy #RASTERBAR		; custom rasterbar colour
rasterbar_colour equ *-1
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
check_play_flag	
	lda is_playing_flag 
	beq check_rasterbar_flag
	jmp check_play_flag 	
check_rasterbar_flag
	lda #0
rasterbar_toggler equ *-1
	bpl do_rmtplay		; a positive value means the rasterbar is not displayed 
	sty COLBK		; background colour
	sty COLPF2		; playfield colour 2
do_rmtplay
	jsr rmt_play		; setpokey + 1 play
	ldy #$00		; black colour value
	sty WSYNC		; horizontal sync
	sty COLBK		; background colour
	sty COLPF2		; playfield colour 2 
	beq loop                ; unconditional

;-----------------

; VBI loop

vbi
	sta WSYNC		; horizontal sync, so we're always on the exact same spot
	ldy KBCODE		; Keyboard Code  
	ldx <line_4		; line 4 of text
	lda SKSTAT		; Serial Port Status
	and #$08		; SHIFT key being held?
	bne set_line_4		; nope, skip the next ldx
	ldx <line_5		; line 5 of text (toggled by SHIFT) 
	tya
	eor #$40		; invert the SHIFT key flag so it will be ignored later
	tay
set_line_4  
	stx txt_toggle		; write to change the text on line 4 
	
check_key_pressed 	
	lda SKSTAT		; Serial Port Status
	and #$04		; last key still pressed?
	beq check_key_pressed_a	; yes if equal
	jmp continue		; if not, nothing else to do here 
check_key_pressed_a
	ldx #0
held_key_flag equ *-1
	bpl check_keys
	jmp continue_b		; a key is being held... skip ahead immediately 
	
check_keys
	; check all keys that have a purpose here... 
	
check_key_space
	cpy #$21		; Spacebar?
	beq toggle_rasterbar	; yes => toggle the rasterbar display 
	
;check_key_1
;	cpy #$1F		; 1 key?
;	beq dec_rasterbar_colour
	
;check_key_2
;	cpy #$1E		; 2 key?
;	beq inc_rasterbar_colour
	
check_key_left
	cpy #$06
	beq dec_songline_seek

check_key_right
	cpy #$07
	beq inc_songline_seek
	
check_key_p
	cpy #$0A
	beq play_pause_toggle
	
check_key_esc 
	cpy #$1C		; ESCape key? 
	bne continue		; nope => loop 

;-----------------
	
stopmusic 
	jsr rmt_silence		; stop RMT and reset the POKEY registers
	mwa oldvbi VVBLKI	; restore the old vbi address
	ldx #$00		; disable playfield 
	stx SDMCTL		; write to Direct Memory Access (DMA) Control register
	dex			; underflow to #$FF
	stx CH			; write to the CH register, #$FF means no key pressed
	jsr wait_vblank		; wait for vblank before continuing
	jmp (DOSVEC)		; return to DOS, or Self Test by default

;-----------------

; rasterbar_colour

;dec_rasterbar_colour
;	dec rasterbar_colour
;	dex 			; 0 -> FF 
;	bmi continue_a		; skip ahead and set the held key flag! 

;inc_rasterbar_colour
;	inc rasterbar_colour
;	dex    			; 0 -> FF 
;	bmi continue_a		; skip ahead and set the held key flag! 

;-----------------

; RMT Play/Pause

play_pause_toggle
	lda #0
is_playing_flag equ *-1
	bpl set_pause		; if positive, it is playing, else, it is already paused
set_play
	inc is_playing_flag	; FF -> 00 
	beq set_held_key_flag	; done 
set_pause
	jsr rmt_silence		; pause the player 
	lda #0
	ldy #TRACKS-1
set_pause_a
	sta trackn_audc,y
	dey 
	bpl set_pause_a
	dec is_playing_flag	; 00 -> FF
	bmi set_held_key_flag	; done

;-----------------

songline_seek

dec_songline_seek
	ldy MODUL+15		; songline pointer MSB
	ldx MODUL+14		; songline pointer LSB 

	lda p_song
	sub #TRACKS+TRACKS	; once -> same line plays again, so subtract twice this number!
	sta p_song 
	scs:dec p_song+1	; in case the boundary is crossed, the pointer MSB will increment as well
	
dec_songline_seek_a
	cpy p_song+1		; compare the p_song MSB to the one from the module
	bcs dec_songline_seek_b	; if the module value is lower, everything is mostly fine... do an extra check before!
	sty p_song+1		; else, revert the changes to it 

dec_songline_seek_b
	cpx p_song		; compare the p_song LSB to the one from the module
	bcc dec_songline_seek_c	; if the module value is lower, everything is fine
	stx p_song 		; overwrite the earlier changes to it	
	
dec_songline_seek_c
	
	; uhhh..... extra check necessary here! Things appear to work ok but this is not perfect, it could jump to garbage!
	
inc_songline_seek
	jsr GetSongLine		; hopefully this will work...
	ldx #$FF
	bmi continue_a		; skip ahead and set the held key flag! 

;-----------------
	
toggle_rasterbar 
	lda rasterbar_toggler	; rasterbar flag, a negative value means the rasterbar display is active 
	eor #$FF		; invert bits 
	sta rasterbar_toggler	; overwrite the rasterbar flag, execution continues like normal from here 
	
;-----------------

set_held_key_flag
	dex			; 0 -> FF 
	bmi continue_a		; skip ahead and set the held key flag! 
continue			; do everything else during VBI after the keyboard checks 
	ldx #0			; reset the held key flag! 
continue_a 			; a new held key flag is set when jumped directly here
	stx held_key_flag
continue_b 			; a key was detected as held when jumped directly here

;-----------------

calculate_time 
	lda is_playing_flag 
	bmi notimetolose	; paused -> no time counter increment 
	dec v_frame		; decrement the frame counter
	bne notimetolose	; not 0 -> a second did not yet pass
	lda #0
framecount equ *-1		; 50 or 60, defined by the region initialisation
	sta v_frame		; reset the frame counter
	bne addasecond		; unconditional
	nop
v_frame equ *-1			; the NOP instruction is overwritten by the frame counter
	
addasecond
	sed			; set decimal flag first
	lda #0
v_second equ *-1
	clc			; clear the carry flag first, the keyboard code could mess with this part now...
	adc #1			; carry flag is clear, add 1 directly
	sta v_second
	cmp #$60		; 60 seconds, must be a HEX value!
	bne cleardecimal 	; if not equal, no minute increment
	ldy #0			; will be used to clear values quicker
	
addaminute
	lda #0
v_minute equ *-1
	adc #0			; carry flag is set above, adding 0 will add 1 instead
	sta v_minute
	sty v_second		; reset the second counter
cleardecimal 
	cld			; clear decimal flag 
notimetolose
	
;-----------------
	
; get the right screen position
	mwa #line_0 DISPLAY

; print minutes
	ldy #48
	lda v_minute
	jsr printhex_direct
	
; print seconds
	ldy #50
	ldx v_second
	txa
	and #1
	beq blink
	lda #":"-$20
blink
	sta (DISPLAY),y 
	iny 
done_blink
	txa
	jsr printhex_direct

; print order	
	ldy #68
	lda #0
v_ord	equ *-1
	jsr printhex_direct
	
; print row
	ldy #76
	lda v_abeat
	jsr printhex_direct
	
	
;;;;
;
; print decay rate and speed, DEBUG CODE!!!!
;	ldy #28
;	lda #RATE
;	jsr printhex_direct
;	
;	ldy #38
;	lda #SPEED
;	jsr printhex_direct 
;
;;;;	
	
;-----------------
	
; draw the volume blocks
	
; index ORA
; #$00 -> COLPF0
; #$40 -> COLPF1 (could be exploited since the font seems to only change brightness), use on numbers and green bars level
; #$80 -> COLPF2 cannot be used!! conflicts with rasterbar, unless I used a DLI
; #$C0 -> COLPF3
	
; current order: red, green (2x), yellow, and numbers in green again...
; line 1: pf3
; line 2-3: pf1, use also on numbers below line 5
; line 4: pf0 

begindraw
	mwa #mode_6+2 DISPLAY	; set the position on screen, offset by 2 in order to be centered
	lda #$c0		; change the colour to red 
	sta colour_bar 
	ldx #TRACKS-1
	
;	; debug code!!!!
;	lda #0
;	ldy #80
;debug_draw
;	sta (DISPLAY),y 
;	iny
;	cpy #116
;	bne debug_draw 
;	; end debug!!!
	
begindraw1
	lda trackn_audc,x	; channel volume and distortion
	and #$0F
	beq reset_decay_a	; 0 = no volume to write into the buffer
	sta temp_volume		; self modifying code
	
begindraw2
	lda trackn_audf,x	; channel frequency
	eor #$FF		; invert the value, the pitch goes from lowest to highest from the left side
	:4 lsr @		; divide by 16
	tay			; transfer to Y

;	; more debug code!!!
;	:3 lsr @ 
;	pha
;	add #82
;	tay
;	lda hexchars,x 
;	sta (DISPLAY),y 
;	pla
;	lsr @
;	tay
;	; end debug!!!
	
begindraw3 
	lda #0
temp_volume equ *-1		; to hopefully speed up the operations without clogging more bytes
	cmp decay_buffer,y	; what is the volume level in memory?
	bcc reset_decay_a	; below the value in memory will be ignored
	beq reset_decay_a	; equal will also be ignored, no point using the same value twice 
reset_decay
	sta decay_buffer,y	; if above the buffer value, write the new value in memory, the decay is now reset for this column
reset_decay_a
	dex
	bpl begindraw1		; repeat until all channels are done 
	
do_index_line	
	inx 			; line index = 0, for a total of 4 lines 
	ldy #15			; 16 columns, including 0 
	
do_index_line_a
	lda decay_buffer,y	; volume value in the corresponding column 
	beq draw_nothing	; a value of 0 is immediately drawing a blank tile on screen 
	
do_index_line_b
	cpx #1
	bcc vol_12_to_15	; X = 0
	beq vol_8_to_11		; X = 1
	cpx #2
	beq vol_4_to_7		; X = 2, else, the last line is processed by default 

vol_0_to_3
	cmp #4
	bcs draw_4_bar 
	cmp #1			; must be equal or above
	beq draw_1_bar		; 1
	cmp #2
	beq draw_2_bar		; 2
	bne draw_3_bar
	
vol_4_to_7
	cmp #8
	bcs draw_4_bar 	
	cmp #5			; must be equal or above
	bcc draw_0_bar		; overwrite with a blank tile, always
	beq draw_1_bar		; 5
	cmp #6
	beq draw_2_bar		; 6
	bne draw_3_bar
	
vol_8_to_11
	cmp #12
	bcs draw_4_bar
	cmp #9			; must be equal or above
	bcc draw_0_bar		; overwrite with a blank tile, always
	beq draw_1_bar		; 9
	cmp #10
	beq draw_2_bar		; 10
	bne draw_3_bar
	
vol_12_to_15 
	cmp #15
	beq draw_3_bar
	cmp #13			; must be equal or above
	bcc draw_0_bar		; overwrite with a blank tile, always 
	beq draw_1_bar		; 13 

draw_2_bar
	lda #60
	bne draw_line1
draw_3_bar
	lda #27
	bne draw_line1
draw_4_bar			
	lda #5
	bne draw_line1
draw_0_bar
	lda #0
	beq draw_nothing
draw_1_bar
	lda #63 

draw_line1
	ora #0
colour_bar equ *-1 

draw_nothing
	sta (DISPLAY),y 
	dey
	bpl do_index_line_a	; continue until all columns were read
	cpx #3
	beq finishedloop	; all channels were done if equal 
	
goloopagain
	lda DISPLAY		; current memory address used for the process
	add #20			; mode 6 uses 20 characters 
	sta DISPLAY		; adding 20 will move the pointer to the next line
	scc:inc DISPLAY+1	; in case the boundary is crossed, the pointer MSB will increment as well
	
verify_line
	cpx #1
	bcc change_line23	; below 1 
change_line4
	lda #$40		; change the colour to green 
	bne colour_changed 
change_line23 
	lda #$00 		; change the colour to yellow 
colour_changed
	sta colour_bar		; new colour is set for the next line 
	jmp do_index_line 	; repeat the process for the next line until all lines were drawn  
	
decay_buffer
	:16 dta $00 
decay_speed
	dta SPEED		; set the speed of decay rate, 0 is no decay, 255 is the highest amount of delay (in frames) 

finishedloop
	ldy #0 			; reset value if needed
	ldx #15			; 16 columns index, including 0 
	
do_decay
	dec decay_speed
	bpl decay_done		; if value is positive, it's over, wait for the next frame 
reset_decay_speed
	lda #SPEED
	sta decay_speed		; reset the value in memory, for the next cycle
decay_again 
	lda decay_buffer,x
	beq decay_next		; 0 equals no decay 
	sub #RATE 
	bpl decay_again_a	; if positive, write the value in memory 
	tya
decay_again_a
	sta decay_buffer,x	; else, write 0 to it
decay_next
	dex			; next column index
	bpl decay_again		; repeat until all columns were done 
decay_done
	
;-----------------

return_from_vbi
	pla			; since we're in our own vbi routine, pulling all values manually is required
	tay
	pla
	tax
	pla
	sta WSYNC		; horizontal sync, this seems to make the timing more stable
	rti			; return from interrupt

;-----------------

; wait for vblank subroutine

wait_vblank 
	lda RTCLOK+2		; load the real time frame counter to accumulator
wait        
	cmp RTCLOK+2		; compare to itself
	beq wait		; equal means it vblank hasn't began
	rts

;-----------------

; print hex characters for several things, useful for displaying all sort of debugging infos
	
printhex
	ldy #0
printhex_direct     ; workaround to allow being addressed with y in different subroutines
	pha
	:4 lsr @
	;beq ph1    ; comment out if you want to hide the leftmost zeroes
	tax
	lda hexchars,x
ph1	
        sta (DISPLAY),y+
	pla
	and #$f
	tax
	mva hexchars,x (DISPLAY),y
	rts
hexchars 
        dta d"0123456789ABCDEF"
        
;-----------------

; some plaintext data used in few spots
        
txt_NTSC
        dta d"NTSC"*
txt_PAL
        dta d"PAL"*,d" "
txt_VBI
	dta d"xVBI (Stereo)"
        
;-----------------
        
; Display list

dlist       
	:5 dta $70
	dta $42,a(line_0)	; ANTIC mode 2
	:3 dta $70
	dta $46,a(mode_6)	; ANTIC mode 6, 20 characters wide
	:3 dta $06 
	:1 dta $02		; middle line is mode 2
	dta $42,a(line_0a)	; ANTIC mode 2
	:2 dta $70
	:3 dta $02
	dta $42			
txt_toggle
	dta a(line_4)		; memory address set to line_4 by default, or line_5 when SHIFT is held
	:5 dta $70
	dta $42,a(line_6)	; 1 final line of mode 2
	dta $41,a(dlist)	; Jump and wait for vblank, return to dlist
	
;-----------------

; line counter spacing table for instrument speed from 1 to 16

tabpp       
	dta 156,78,52,39,31,26,22,19,17,15,14,13,12,11,10,9 

;-----------------

oldvbi	
	dta a(0)		; vbi address backup
	
;-----------------

; text strings, each line holds 40 characters, line 5 is toggled with the SHIFT key

	org $A000		; must be at this memory address 

line_0	dta d"                                        "

;line_0	dta d"                Decay Rate: 00 Speed: 00"

line_0a	dta d"  Time: 00:00        Order: 00 Row: 00  "

line_1	dta d"Line 1                                  "
line_2	dta d"Line 2                                  "
line_3	dta d"Line 3                                  "
line_4	dta d"Line 4 (hold SHIFT to toggle)           "
line_5	dta d"Line 5 (SHIFT is being held right now)  "

;line_1	dta d"Now playing...                          "
;line_2	dta d"Flob - Escape from the Lab              "
;line_3	dta d"It's a really cool game too! Try it!    "
;line_4	dta d"Testing my VU Meter code, works nicely! "
;line_5	dta d"I am also a fat blob, but shhh... :D    "

;

mode_6	dta d"                    "
mode_6a	dta d"                    "
mode_6b	dta d"                    "
mode_6c	dta d"                    "

mode_2d dta $43,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45
	dta $45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$45,$41 

;

line_6	dta d"VinsCool, 2022                          "

;-----------------

; load font into memory, this was put at the very end to avoid overwriting other data

        org FONT                ; characters set memory location
        ins "font.fnt"          ; some cool looking font

;-----------------

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

