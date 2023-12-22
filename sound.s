
; NOTE: much more work on sound could be done.
; Experimental code is left in here in case
; I ever get back to working on this.

init_sound subroutine
            lda #0
            sta sound_delay
            sta sound_duration
            sta sound_count
            rts

toggle_sound subroutine
            lda sound_enabled
            eor #1
            sta sound_enabled
            bne .1
            lda #0
            sta sound_count
.1          rts

update_sound subroutine
            BEGIN_EVENT UpdateSound
            lda sound_throttle
            beq .1
            dec sound_throttle
.1          lda sound_enabled
            beq .2

            ; TODO: save/restore X and Y
            ; TODO: generate some sound
            ; txa
            ; pha
            ; tya
            ; pha

            lda sound_count
            beq .Y
            dec sound_count
            bne .Y

            sta   $c030
            inc   $c030
            dec   $c030

            dec sound_duration
            beq .Y

            lda sound_delay
            sta sound_count
            ; dec sound_delay
            ; bne .Y
            ; lda #1
            ; sta sound_delay

            ; ldx #1
; .X          sta $c030
            ; nop
            ; nop
            ; sta $c030
            ; lda #8
            ; jsr WAIT
            ; dex
            ; bne .X

.Y
            ; pla
            ; tay
            ; pla
            ; tax
            ; lda #16
            ; sta sound_delta
.2          END_EVENT UpdateSound
            rts

; TODO: consider which callers want registers saved

play_ball_send
            rts

; a: y index of block hit (0 - 9)
; NOTE: playing a sound on every wall hit gets too noisy
play_wall_hit
            rts

; a: y index of block hit (0 - 9)
play_block_hit
            tay
            lda sound_duration
            bne .Z
            lda #1
            sta sound_count
            lda .delays,y
            sta sound_delay
            lda .durations,y
            sta sound_duration
.Z          rts

; .delays     dc.b  3, 3, 3, 4,5,6,7,8,9,10
; .durations  dc.b 13,13,13,10,8,8,7,6,5, 4

.delays     dc.b 6,6,7,7,8,8,9,9,10,10
.durations  dc.b 8,8,7,7,6,6,5,5,4,4

play_block_destroyed
play_appl_capture
            lda sound_duration
            ; bne .ZZ
            lda #2  ;20
            sta sound_delay
            lda #1
            sta sound_count
            lda #20 ;4
            sta sound_duration
.ZZ         rts
play_ball_done
play_wave_done
play_game_over
            rts


            if 0

; title screen tune?
; start game sound?

laser       subroutine
            LDA   #$00
            STA   $FF
            LDA   #$FF
            STA   $FE
.1          LDA   #$00
            STA   $C030
            INC   $C030
            DEC   $C030
            LDX   $FF
.2          DEX
            BNE   .2
            DEC   $FE
            BEQ   .3
            INC   $FF
            JMP   .1
.3          RTS


; short white noise for each row, with longer "decay" on last row
; scrolling block letters?

; play_block_row?
; play_last_row?

; play_ball_launch subroutine
; ; laser?

; play_game_over subroutine

; play_block_done subroutine

; play_got_apply subroutine

; play_wall_bounce subroutine

; play_block_bounce subroutine
; bounce_sound subroutine
;             rts

;             ldx #8
; .1          sta $c030
;             lda #12
;             jsr WAIT
;             dex
;             bne .1

;             ; lda #0
;             ; jsr WAIT
;             rts

;
; On Entry:
;   A: wait value
;
; On Exit:
;   X,Y: unchanged
;
WAIT            SEC
.WAITA          PHA
.WAITB          SBC #$01
                BNE .WAITB
                PLA
                SBC #$01
                BNE .WAITA
                ; SAME_PAGE_AS .WAITA
                RTS

; Sound code from Galactic Empires

play_1110   subroutine          ; laser shot
            LDA #1
            STA $51
            LDA #1
            STA $52
            LDA #75
            STA $53
            LDA #50     ;**#100
            STA $54
            JMP sound_825

sound_816   subroutine
            LDX $51         ; 0330
.loop       JSR make_noise  ; 0332
            TXA             ; 0335
            BNE .loop       ; 0336
            RTS             ; 0338

sound_825   subroutine
            CLD             ; 0339
            LDA $53         ; 033A
            STA $50         ; 033C
            SEC             ; 033E
            SBC $54         ; 033F
            BCC .pitch_up   ; 0341

.pitch_down ADC #$00        ; 0343
            STA $55         ; 0345
.loop1      JSR sound_816   ; 0347
            DEC $50         ; 034A
            DEC $55         ; 034C
            BNE .loop1      ; 034E
            RTS             ; 0350

.pitch_up   EOR #$FF        ; 0351
            ADC #$02        ; 0353
            STA $55         ; 0355
.loop2      JSR sound_816   ; 0357
            INC $50         ; 035A
            DEC $55         ; 035C
            BNE .loop2      ; 035E
            RTS             ; 0360


play_1760   subroutine          ; short crunch
            LDA #5
            STA $51
            LDA #1
            STA $52
            LDA #<jmp_128
            STA mod_888+1
            JSR sound_865
            LDA #10
            STA $51
            LDA #<jmp_129
            STA mod_888+1
            JSR sound_865
            LDA #<jmp_130
            STA mod_888+1
            JMP sound_865

play_1310   subroutine          ; short explosion
            LDA #5
            STA $51
            LDA #1
            STA $52
            LDA #<jmp_128
            STA mod_888+1
            JSR sound_865
            LDA #<jmp_129
            STA mod_888+1
            JSR sound_865
            LDA #<jmp_130
            STA mod_888+1
            LDA #15
            STA $51
            LDA #1
            STA $58
.loop       LDA $58
            STA $52
            JSR sound_865
            LDA $58
            INC $58
            CMP #2          ;#10
            BNE .loop
            LDA #15
            STA $52
            JMP sound_865

sound_865   LDX $51         ; 0361
            LDA #$60        ; 0363 ; was #$E0
            STA mod_noise+2 ; 0365
            LDA #$00        ; 0368
            STA mod_noise+1 ; 036A
loop_noise  INC mod_noise+1 ; 036D
            BNE mod_noise   ; 0370
            INC mod_noise+2 ; 0372
mod_noise   LDA $E00E       ; 0375
mod_888     JMP jmp_130     ; 0378 ; 889 == $379 (128,129,130 == $80,$81,$82)
            LSR             ; 037B
            LSR             ; 037C
            LSR             ; 037D
            LSR             ; 037E
            LSR             ; 037F
jmp_128     LSR             ; 0380
jmp_129     LSR             ; 0381
jmp_130     CLC             ; 0382
            ADC #$01        ; 0383
            STA $50         ; 0385
            JSR make_noise  ; 0387
            TXA             ; 038A
            BNE loop_noise  ; 038B
            RTS             ; 038D


make_noise  subroutine
            STA $C030       ; 038E
            LDA $52         ; 0391
            STA $57         ; 0393
            LDY $50         ; 0395
.delay1     DEY             ; 0397
            BNE .delay1     ; 0398
            STA $C030       ; 039A
.loop       LDY $50         ; 039D
.delay2     DEY             ; 039F
            BNE .delay2     ; 03A0
            CLC             ; 03A2
            LDA $50         ; 03A3
            BEQ .skip1      ; 03A5
            ADC $56         ; 03A7
            STA $56         ; 03A9
            BCC .skip2      ; 03AB
.skip1      TXA             ; 03AD
            BEQ .skip2      ; 03AE
            DEX             ; 03B0
.skip2      DEC $57         ; 03B1
            BNE .loop       ; 03B3
            RTS             ; 03B5

            endif
