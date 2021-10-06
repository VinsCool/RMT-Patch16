pp2scont_check_skctl
	cmp #$06                ; "Distortion 6", or rather, Slot 6
	bne skctlskip           ; Skip the hijack, and runs the failsafe code to make sure it does not keep incorrect data in memory
	lda #$8B                ; Two-Tone mode, affects Channel 1 and 2
	jmp skctlstore
skctlskip
        lda #3                  ; Failsafe to make sure the SKCTL register is always in normal mode in any case
skctlstore
        sta v_skctl
        
        IFT STEREOMODE==1
        sta v_skctl2	        ; Continue like normal from here
        EIF
        
--------------------------------------------------

        IFT FEAT_IS_VISUALP==1
	dta frqtabpure-frqtab,$a0     ; Two-Tone Filter will use the same Distortion A table for now
        ELS
        dta frqtabbuzzy-frqtab,$c0    ; for compatibility sake, Distortion C Buzzy is yet again copied into slot 6
        EIF
        
-------------------------------------------------

; wait for vblank subroutine

wait_for_vblank
        lda RTCLOK+2
wait
        cmp RTCLOK+2
        beq wait
        rts

--------------------------------------------------

start
        mwa #dlist rDLISTL
        ldx #255
        ldy #0
	mva rRANDOM v_colour1               ; random colours, used during VBI, RASTERMUSICTRACKER, LOOP, etc
	mva rRANDOM v_colour2
	mva rRANDOM v_colour3

start_wait
	mwa #dlist rDLISTL
        mva #>FONT rCHBASE
        mva #$0F rCOLPF1
        tya
        sub #40
        bcs start_invert
	mva txt_start,y scr,y
        sty rCOLBK
        stx rCOLPF2
	jmp start_loop

start_invert
	mva #0 scr-40,y
	mva v_colour2 rCOLBK
	stx rCOLPF2	

start_loop
        jsr wait_for_vblank
        dex
        iny
        cmp #90
        bne start_wait
        ldx #30
        ldy #0
        
start_loop2
        mwa #dlist rDLISTL
        mva #>FONT rCHBASE
        mva #0 rCOLPF2
        mva rRANDOM rCOLPF1
        mva v_colour2 rCOLBK
        jsr wait_for_vblank
        mva txt_uwu,y scr,y+
        cpy #3
        sne:ldy #0
        dex
        bne start_loop2

; I had some fun ok don't judge me x3
; ...
; loading the RMT module


txt_start
        dta d"          Moo... I'm a cat...           "
       ;dta d"lolololololololololololololololololololo" ; template for 40 characters

txt_uwu
        dta d":3c"
        
-----------------------------------------------

; quick and dirty clarinet hack

check_16bit_ch12       
        lda trackn_audctl,x
        and #$50
        beq check_16bit_ch34
        cpx #0 ; ch1
        beq try_ch13
        cpx #1 ; ch2
        beq try_ch24
        
check_16bit_ch34
        lda trackn_audctl,x        
        and #$28
        beq continue_note_checks
        cpx #2 ; ch3
        beq try_ch13
        cpx #3 ; ch4
        beq try_ch24
        bne continue_note_checks
        
try_ch13        
        mwa #txt_notes_oct3 infosrc
        jmp printnote_fallback_direct
        
try_ch24 
        mwa #txt_notes_oct2 infosrc
        jmp printnote_fallback_direct
        
--------------------------------------------

start
        mwa #dlist rDLISTL
	mva rRANDOM v_colour1               ; random colours, used during VBI, RASTERMUSICTRACKER, LOOP, etc
	mva rRANDOM v_colour2
	mva rRANDOM v_colour3
	ldx #$FF

start_loop
        ldy #4
start_loop2        
        jsr wait_for_vblank
        mwa #dlist rDLISTL
        mva v_colour2 rCOLBK
start_loop3        
        stx rCOLPF2
        dey
        bne start_loop2

        txa
        sub #$11
        tax

        cpx #0
        bne start_loop        

start_loop4
        jsr wait_for_vblank
        mwa #dlist rDLISTL
        mva #>FONT rCHBASE 
        mva v_colour2 rCOLBK
        mva #0 rCOLPF2
        mva #15 rCOLPF1
        
        cpy #40
        beq start_loop5
        mva txt_start,y scr,y
        iny

start_loop5
        inx
        cpx #120
        bne start_loop4
        
--------------------------------------------------

; distortion 2 hack code dump...

	cmp #$02               ; slot 2?
	beq hijack_dist2_mono  ; yes, jump to this hijack
	
hijack_dist2_mono
        tay                                  ; load the RMT slot value 
        cpx #$02                             ; channel 3?
        beq hijack_dist2_ch3                 ; yes, jump straight to the next part
        cpx #$00                             ; channel 1?
        beq hijack_dist2_ch1                 ; yes, jump straight to the next part
        jmp no_hijack                        ; nope, skip the hijack

hijack_dist2_ch3
        lda #$20                             ; 1.79mhz ch3
        jmp hijack_dist2_done                ; finished hijacking the AUDCTL value, nothing else has to be done
hijack_dist2_ch1
        lda #$40                             ; 1.79mhz ch1
hijack_dist2_done
        ora v_dist2flag
        sta v_dist2flag


        
	cmp #$02                ; slot 2?
	beq hijack_dist2_stereo ; yes, jump to this hijack
	
hijack_dist2_stereo
        ldy tmp2                             ; load the RMT slot value 
        cpx #$06                             ; channel 3?
        beq hijack_dist2_ch3_stereo          ; yes, jump straight to the next part
        cpx #$04                             ; channel 1?
        beq hijack_dist2_ch1_stereo          ; yes, jump straight to the next part
        jmp no_hijack                        ; nope, skip the hijack

hijack_dist2_ch3_stereo
        lda #$20                             ; 1.79mhz ch3
        jmp hijack_dist2_done_stereo         ; finished hijacking the AUDCTL value, nothing else has to be done
hijack_dist2_ch1_stereo
        lda #$40                             ; 1.79mhz ch1
hijack_dist2_done_stereo
        ora v_dist2flag2
        sta v_dist2flag2
        jmp no_hijack
        
        
rmt_p4
	IFT FEAT_AUDCTLMANUALSET
	lda trackn_audctl+0
	ora trackn_audctl+1
	ora trackn_audctl+2
	ora trackn_audctl+3
	
	ora v_dist2flag
	
	tax
	
	lda #0
	sta v_dist2flag
	
	ELS
	ldx #0
	EIF
	
qq5
	stx v_audctl
	IFT TRACKS>4
	IFT FEAT_AUDCTLMANUALSET
	lda trackn_audctl+4
	ora trackn_audctl+5
	ora trackn_audctl+6
	ora trackn_audctl+7
	
	ora v_dist2flag2
	
	tax
	
	lda #0
	sta v_dist2flag2
	
	ELS
	ldx #0
	EIF
	
v_dist2flag      	org *+1

        IFT STEREOMODE==1
v_dist2flag2      	org *+1
        EIF
        
--------------------------------------------------------------

; 16-bit notes display workaround

printnote_checks 
        ldx zTMP1              ; index x is used to know which channel is currently being used
        lda trackn_audc,x      ; start with the AUDC value of the channel identified by x
        tay                    ; backup the value for the first check
        and #$0F               ; clear the distortion bits
        beq printnote_off      ; volume is 0

        IFT STEREOMODE==1
checks_0                       ; temporary 16-bit workaround
        txa
        and #4                 ; second POKEY? The value of index x would be between 4 to 8 included
        beq checks_1_mono      ; it is not, therefore, the first chip is being updated
checks_1_stereo 
        lda v_audctl2
        pha
        and #$08
        beq checks_3_stereo
checks_2_stereo
        pla
checks_2a_stereo   
        cpx #5
        beq printnote_fallback
        cpx #7
        beq printnote_fallback
        bne continue_note_checks
checks_3_stereo
        pla
        and #$10
        beq continue_note_checks
        bne checks_2a_stereo
        EIF
        
checks_1_mono                  ; temporary 16-bit workaround
        lda v_audctl
        pha
        and #$08
        beq checks_3_mono
checks_2_mono
        pla
checks_2a_mono        
        cpx #1
        beq printnote_fallback
        cpx #3
        beq printnote_fallback
        bne continue_note_checks
checks_3_mono
        pla
        and #$10
        beq continue_note_checks
        bne checks_2a_mono
        
---------------------------------------------------------------

; print VCOUNT
	mwa #scr+358 zARG0
	lda rVCOUNT
	jsr printhex
			
; print RANDOM
	mwa #scr+438 zARG0
	lda rRANDOM
	jsr printhex
	
; print v_frame
	mwa #scr+518 zARG0
	lda v_frame
	jsr printhex

----------------------------------------------------------------

printhex
	ldy #0
printhex_direct     ; workaround to allow being addressed with y in different subroutines
	pha
	:4 lsr @
	;beq ph1    ; comment out if you want to hide the leftmost zeroes
	tax
	lda hexchars,x
ph1	
        sta (zARG0),y+
	pla
	and #$f
	tax
	mva hexchars,x (zARG0),y
	rts

hexchars 
        dta d"0123456789ABCDEF"

----------------------------------------------------------------

printhex
	ldy #0
printhex_direct     ; workaround to allow being addressed with y in different subroutines
        tax
        and #$F0
        :4 lsr @    ; move the nybble to the rightmost position
        sta hexbuff
        txa
        and #$0F
        sta hexbuff+1
        ldx #0      ; loop buffer, 2 characters
ph0
        lda hexbuff,x
ph1        
        sub #10
        bpl ph2     ; A to F, else 0 to 9
ph1_a
        lda hexbuff,x
        ora #$10    ; offset to ATASCII characters 0 to 9
        bne ph3     ; unconditional
ph2
        lda hexbuff,x
        add #$17    ; offset to ATASCII characters A to F
ph3
        sta (zARG0),y+
        inx
        cpx #2
        bne ph0     ; do it again
        rts
hexbuff org *+2

---------------------------------------------------------------
