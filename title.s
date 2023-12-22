
; Drawing and animation code not directly related to
;   core game operation.

title_screen subroutine
            jsr clear1
            jsr erase_screen_grid

            ldy #0
.1          sty ypos
            jsr fill_grid_row
            ldy ypos
            iny
            cpy #grid_height
            bne .1

            sta primary
            sta fullscreen
            sta hires
            sta graphics

            ldy #2
            jsr delay

            ldx #0
            ldy #7
            jsr scroll_presents

            ldy #6
            jsr delay

            ldx #1
            ldy #14
            jsr scroll_presents

            ldy #8
            jsr delay

            lda #8
            jsr reset_logo
            jsr draw_logo
.2          jsr animate_logo
            bcc .3
            bit keyboard
            bpl .2
            jsr abort_logo
            jmp .2
.3          rts

;-----------------------------------------------------------
;
; on entry:
;   x: 0 (callaco) or 1 (presents)
;   y: end scroll line
;
scroll_presents subroutine
            stx xpos
            sty .mod+1
            ldy #191
.1          sty ycount
            ldx xpos
            jsr draw_presents
            lda #$08
            jsr wait
            ldy ycount
            dey
.mod        cpy #7
            bcs .1
            rts
;
; on entry:
;   x: 0 (callaco) or 1 (presents)
;   y: top line to draw at
;
draw_presents subroutine

            lda .offsets+1,x
            sta .mod+1
            lda .offsets+0,x
            tax
.1          sty ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy #3
.2          lda callaco,x
            sta (screenl),y
            inx
            iny
            cpy #3+10
            bne .2
.mod        cpx #$ff
            beq .3
            ldy ypos
            iny
            cpy #192
            bne .1
.3          rts

.offsets    dc.b 0,60,120

callaco     hex 00787933307067670F00
            hex 00181833303066600C00
            hex 00187833307067600C00
            hex 00181833303066600C00
            hex 00781973733366670F00
            hex 00000000000000000000

presents    hex 401F1F3E3E3E667C7901
            hex 4019330606066E301800
            hex 401F1F1E3E1E7E307801
            hex 40013306300676304001
            hex 4001333E3E3E66307801
            hex 00000000000000000000

;-----------------------------------------------------------

; NOTE: Could delay left to right as well
;   to get more of a "tiling" animation

close_screen_grid subroutine
            ldy #0
.1          sty ypos
            cpy #3
            bne .2
            jsr erase_game_over
            ldy ypos
.2          jsr fill_grid_row

            ; TODO: sound instead?
            lda #$80
            jsr wait

            ldy ypos
            iny
            cpy #grid_height
            bne .1
            rts

open_screen_grid subroutine
            ldy #0          ;1          ; skip top line
.1          sty ypos
            jsr erase_grid_row

            ; TODO: sound instead?
            lda #$80
            jsr wait

            ldy ypos
            iny
            cpy #grid_height
            bne .1
            rts
;
; on entry:
;   y: grid row
;
fill_grid_row subroutine
            ldx grid_rows+1,y
            dex
            stx xpos
            tya
            lsr
            lda #$0
            ror
            sta block_color
            lda grid_rows,y
            tay
            iny
.loop1      sty block_index
            jsr draw_title_block
            ldy block_index
            iny
            cpy xpos
            bne .loop1
            rts
;
; on entry:
;   y: grid row
;
erase_grid_row subroutine
            ldx grid_rows+1,y
            dex
            stx xpos
            lda grid_rows,y
            tay
            iny
.loop1      sty block_index
            jsr erase_block
            ldy block_index
            iny
            cpy xpos
            bne .loop1
            rts

grid_rows   dc.b    grid_width*0
            dc.b    grid_width*1
            dc.b    grid_width*2
            dc.b    grid_width*3
            dc.b    grid_width*4
            dc.b    grid_width*5
            dc.b    grid_width*6
            dc.b    grid_width*7
            dc.b    grid_width*8
            dc.b    grid_width*9
            dc.b    grid_width*10

;-----------------------------------------------------------

game_over_top = 64
game_over_bottom = 82
game_over_left = 20
game_over_right = 35

draw_game_over subroutine
            ldx #0
            ldy #game_over_top
.1          sty ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy #game_over_left
            lda #0
            sta (screenl),y
            iny
.2          lda game_over_image,x
            sta (screenl),y
            inx
            iny
            cpy #game_over_right-1
            bne .2
            lda #0
            sta (screenl),y
            ldy ypos
            iny
            cpy #game_over_bottom
            bne .1
            rts

erase_game_over subroutine
            ldx #game_over_top
.1          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            ldy #game_over_left
            lda #0
.2          sta (screenl),y
            iny
            cpy #game_over_right
            bne .2
            inx
            cpx #game_over_bottom
            bne .1
            rts

game_over_image
            hex 00000000000000000000000000
            hex D4AAD5AAD5AAD5AAD5AAD5AA95
            hex D4AAD5AAD5AAD5AAD5AAD5AA95
            hex 94000000000000000000000094
            hex 94000000000000000000000094
            hex 94000000000000000000000094
            hex 9470674F7F73037C1973730394
            hex 9430604C1933004C1933300694
            hex 9430674F1973014C1973710394
            hex 9430664C1933004C1933300694
            hex 9470674C1973037C7971330694
            hex 94000000000000000000000094
            hex 94000000000000000000000094
            hex 94000000000000000000000094
            hex D4AAD5AAD5AAD5AAD5AAD5AA95
            hex D4AAD5AAD5AAD5AAD5AAD5AA95
            hex 00000000000000000000000000
            hex 00000000000000000000000000

;-----------------------------------------------------------

draw_wave_best subroutine

            ldx #0
            ldy #wave_y
.1          sty ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy #wave_x
.2          lda wave_best,x
            sta (screenl),y
            inx
            iny
            cpy #wave_x+6
            bne .2
            ldy ypos
            iny
            cpy #wave_y+13
            bne .1
            rts

wave_best   hex 30667C197363
            hex 30664C193360
            hex 30667C197301
            hex 30664C193360
            hex 707F4C797163
            hex 000000000000
            hex 000000000000
            hex 000000000000
            hex 0030667C1963
            hex 0030660C1863
            hex 0070676C7903
            hex 0030664C1963
            hex 0030667C1963

;-----------------------------------------------------------
;
; clear primary screen to black
;
clear1      subroutine
            ldx #0
            txa
            ldy #$20
.1          sty .2+2
.2          sta $2000,x     ; modified
            inx
            bne .2
            iny
            cpy #$40
            bne .1
            rts

;-----------------------------------------------------------

; NOTE: This digit drawing code was rewritten after
;   the general sound performance pass was done,
;   so some uneveness in sound processing may
;   have been introduced.

; Also, this code could have been much simpler if digits
;   were 6 pixels wide with 1 pixel of spacing, but
;   in order to make text look nicer, 2 pixels of
;   space was used, requiring shifting cases.

; The "_l2" drawing case is there to handle drawing
;   digits at the far right of the grid, where they
;   would otherwise collide with the grid border.

;
; set next location to draw text
;
; on entry:
;   x: x position in bytes
;   y: y position in lines
;
set_text_xy subroutine
            stx xpos
            sty ypos
            rts
;
; draw 3 digit number
;
; on entry:
;   x: high 1 digit
;   a: low 2 digits
;
draw_digits3 subroutine
            tay
            and #$0f
            pha
            tya
            lsr
            lsr
            lsr
            lsr
            pha
            txa
            pha
            sta top_digit

draw_digits ldx xpos
            cpx #35
            beq .2

            pla
            bmi .1
            jsr draw_digit_l1
.1          inc xpos
            pla
            jsr draw_digit_r0
            inc xpos
            jsr update_sound
            pla
            jsr draw_digit_r1
            inc xpos
            rts

.2          pla
            bmi .3
            jsr draw_digit_l2
.3          inc xpos
            pla
            jsr draw_digit_l1
            inc xpos
            jsr update_sound
            pla
            jsr draw_digit_r0
            inc xpos
            rts
;
; update 3 digit number
;
; NOTE: Only the top/100's digit drawing is skipped if it hasn't changed.
;   The 10's and 1's are always draw to balance timing for sound purposes.
;
; on entry:
;   x: high 1 digit
;   a: low 2 digits
;
update_digits3 subroutine
            pha
            ldy #-1
            txa
            and #$0f
            cmp top_digit
            beq .1
            sta top_digit
            tay
.1          pla
            tax
            and #$0f
            pha
            txa
            lsr
            lsr
            lsr
            lsr
            pha
            tya
            pha
            jmp draw_digits

erase_digits3 subroutine
            ldx xpos
            cpx #35
            bne erase_digits_l1

erase_digits_l2
            ldy #%10011111
            bne .0          ; always
erase_digits_l1
            ldy #%10111111
.0          sty .mod+1

            BEGIN_EVENT EraseChars
            lda #5
            sta ycount
            ldx ypos
            SET_PAGE
.1          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            ldy xpos
            dey
            lda (screenl),y
.mod        and #$ff
            sta (screenl),y
            iny
            lda #0
            sta (screenl),y
            iny
            sta (screenl),y
            iny
            sta (screenl),y
            inx
            dec ycount
            bne .1
            CHECK_PAGE
            END_EVENT EraseChars
            rts

; NOTE: This could be more efficient by using
;   pre-shifted font characters but it's not used
;   frequently enough to warrant that.
draw_digit_l2 subroutine
            BEGIN_EVENT DrawChar
            tay
            ldx font_offsets,y
            lda font_offsets+1,y
            sta .mod+1
            lda ypos
            sta ycount
            SET_PAGE
.1          ldy ycount
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy xpos
            lda font,x

            sta temp        ; 00abcdef
            asl             ; 0abcdef0
            lsr temp        ; 000abcde
            ror             ; f0abcdef
            lsr temp        ; 0000abcd
            ror             ; ef0abcde
            lsr             ; 0ef0abcd
            sta temp        ; 0ef0abcd

            lda (screenl),y
            eor temp
            and #%11110000
            eor temp
            sta (screenl),y
            dey
            lda (screenl),y
            eor temp
            and #%10011111
            eor temp
            sta (screenl),y

            inx
            inc ycount
.mod        cpx #$ff
            bne .1
            CHECK_PAGE
            END_EVENT DrawChar
            rts

draw_digit_l1 subroutine
            BEGIN_EVENT DrawChar
            tay
            ldx font_offsets,y
            lda font_offsets+1,y
            sta .mod+1
            lda ypos
            sta ycount
            SET_PAGE
.1          ldy ycount
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy xpos
            lda font,x
            lsr
            sta (screenl),y
            dey
            lda (screenl),y
            bcc .2
            ora #%01000000
            bne .3          ; always
.2          and #%10111111
.3          sta (screenl),y
            inx
            inc ycount
.mod        cpx #$ff
            bne .1
            CHECK_PAGE
            END_EVENT DrawChar
            rts

draw_digit_r0 subroutine
            ldy #$ea        ; nop
            bne .0
draw_digit_r1
            ldy #$0a        ; asl acc
.0          sty .mod1

            BEGIN_EVENT DrawChar
            tay
            ldx font_offsets,y
            lda font_offsets+1,y
            sta .mod2+1
            lda ypos
            sta ycount
            SET_PAGE
.1          ldy ycount
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy xpos
            lda font,x
.mod1       asl
            sta (screenl),y
            inx
            inc ycount
.mod2       cpx #$ff
            bne .1
            CHECK_PAGE
            END_EVENT DrawChar
            rts

font_offsets
            dc.b 0,5,10
            dc.b 15,20,25
            dc.b 30,35,40
            dc.b 45,50

font        dc.b %00111111      ; 0
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00111111

            dc.b %00001100      ; 1
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100

            dc.b %00111111      ; 2
            dc.b %00110000
            dc.b %00111111
            dc.b %00000011
            dc.b %00111111

            dc.b %00111111      ; 3
            dc.b %00110000
            dc.b %00111100
            dc.b %00110000
            dc.b %00111111

            dc.b %00110011      ; 4
            dc.b %00110011
            dc.b %00111111
            dc.b %00110000
            dc.b %00110000

            dc.b %00111111      ; 4
            dc.b %00000011
            dc.b %00111111
            dc.b %00110000
            dc.b %00111111

            dc.b %00111111      ; 6
            dc.b %00000011
            dc.b %00111111
            dc.b %00110011
            dc.b %00111111

            dc.b %00111111      ; 7
            dc.b %00110000
            dc.b %00110000
            dc.b %00110000
            dc.b %00110000

            dc.b %00111111      ; 8
            dc.b %00110011
            dc.b %00111111
            dc.b %00110011
            dc.b %00111111

            dc.b %00111111      ; 9
            dc.b %00110011
            dc.b %00111111
            dc.b %00110000
            dc.b %00111111

;-----------------------------------------------------------

sine_step   =   8
delay_step  =   4
;
; on exit:
;   sec: animation running
;   clc: animation complete
;
animate_logo subroutine

            ldx #4
.1          lda logo_bounce,x
            bne .2
            dex
            bpl .1
            clc                 ; logo complete
            rts

.2          ldx #4
.3          lda logo_delay,x
            beq .4
            dec logo_delay,x
            bpl .9              ; always

.4          lda logo_bounce,x
            beq .9

            lda logo_yind,x
            ldy logo_dyind,x
            bmi .5
            clc
            adc #sine_step
            tay
            sta logo_yind,x
            bpl .7
            sec
            sbc #sine_step*2
            sta logo_yind,x
            tay
            bpl .6              ; always

.5          sec
            sbc #sine_step
            sta logo_yind,x
            tay
            bpl .7
            clc
            adc #sine_step*2
            sta logo_yind,x
            tay

            lda #0
            dec logo_bounce,x
            beq .8

            lda logo_dyoff,x
            eor #$ff
            sta logo_dyoff,x

.6          lda logo_dyind,x
            eor #$ff
            sta logo_dyind,x
.7          lda sine_table,y
            lsr
            lsr
            lsr
            lsr
            eor logo_dyoff,x
            sec
            sbc logo_dyoff,x
.8          sta logo_yoff,x
.9          dex
            bpl .3
            jsr draw_logo
            sec                 ; logo running
            rts
;
; on entry:
;   A: bounce count (max #128)
;
reset_logo  subroutine

            asl
            sec
            sbc #1
            ldx #4
.1          sta logo_bounce,x
            dex
            bpl .1

            ldx #4
            lda #0
            clc
.2          sta logo_delay,x
            adc #delay_step
            dex
            bpl .2

            ldx #4
            lda #0
.3          sta logo_yind,x
            sta logo_dyind,x
            sta logo_yoff,x
            dex
            bpl .3

            ldx #4
            lda #$ff
.4          sta logo_dyoff,x
            dex
            bpl .4
            rts

abort_logo  subroutine

            ldx #4
.1          lda logo_bounce,x
            beq .2
            lda #1
            sta logo_bounce,x
.2          dex
            bpl .1
            rts

logo_delay  dc.b delay_step*0
            dc.b delay_step*1
            dc.b delay_step*2
            dc.b delay_step*3
            dc.b delay_step*4

logo_bounce dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0

logo_yind   dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0

logo_dyind  dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0

logo_yoff   dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0
            dc.b 0

logo_dyoff  dc.b $ff
            dc.b $ff
            dc.b $ff
            dc.b $ff
            dc.b $ff
;
; draw entire Applz logo
;
draw_logo   subroutine

            ldx #0
.1          txa
            pha
            jsr draw_logo_letter
            pla
            tax
            inx
            cpx #5
            bne .1
            rts
;
; draw one letter of Applz logo
;
; on entry:
;   X: letter index
;
draw_logo_letter subroutine

            lda logos_lo,x
            sta .logo_mod+1
            lda logos_hi,x
            sta .logo_mod+2
            lda logo_lefts,x
            sta .xstart_mod+1
            clc
            adc logo_widths,x
            sta .xend_mod+1
            lda logo_tops,x
            clc
            adc logo_yoff,x
            cmp #192
            bcs .exit       ; not visible
            tay
            clc
            adc logo_heights,x
            cmp #192
            bcc .1
            lda #192        ; clip to bottom of screen
.1          sta .yend_mod+1
            ldx #0
.2          sty ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
.xstart_mod ldy #$ff
.logo_mod   lda logo_a,x
            sta (screenl),y
            inx
            iny
.xend_mod   cpy #$ff
            bne .logo_mod
            ldy ypos
            iny
.yend_mod   cpy #$ff
            bne .2
.exit       rts

logo_top    =   34
logo_tops   dc.b logo_top+0
            dc.b logo_top+17
            dc.b logo_top+17
            dc.b logo_top
            dc.b logo_top+17

logo_heights
            dc.b 41
            dc.b 59-17
            dc.b 59-17
            dc.b 41
            dc.b 41-17

logo_lefts  dc.b 1
            dc.b 4
            dc.b 8
            dc.b 11
            dc.b 12

logo_widths dc.b 3
            dc.b 4
            dc.b 3
            dc.b 1
            dc.b 4

logos_lo    dc.b #<logo_a
            dc.b #<logo_p0
            dc.b #<logo_p1
            dc.b #<logo_l
            dc.b #<logo_z

logos_hi    dc.b #>logo_a
            dc.b #>logo_p0
            dc.b #>logo_p1
            dc.b #>logo_l
            dc.b #>logo_z

logo_a      hex 000000
            hex 000000
            hex 552A15
            hex 552A15
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 550214
            hex 552A15
            hex 552A15
            hex 552A15
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 000000
            hex 000000

logo_p0     hex 00000000
            hex 00000000
            hex A8D5AA81
            hex A8D5AA81
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A880A081
            hex A895A081
            hex A8D5AA81
            hex A8D5AA81
            hex A8D5AA81
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex A8800000
            hex 00000000
            hex 00000000

logo_p1     hex 000000
            hex 000000
            hex 552A15
            hex 552A15
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 050014
            hex 550214
            hex 552A15
            hex 552A15
            hex 552A15
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 050000
            hex 000000
            hex 000000

logo_l      hex 00
            hex 00
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex A8
            hex 00
            hex 00

logo_z      hex 00000000
            hex 00000000
            hex 20552A01
            hex 20552A01
            hex 00002001
            hex 00002001
            hex 00002800
            hex 00002800
            hex 00000A00
            hex 00000A00
            hex 00400200
            hex 00400200
            hex 00500000
            hex 00500000
            hex 00140000
            hex 00140000
            hex 00050000
            hex 00050000
            hex 20010000
            hex 20010000
            hex 20552A01
            hex 20552A01
            hex 00000000
            hex 00000000

;-----------------------------------------------------------
;
; on entry:
;   y: repetitions of WAIT #$00
;
delay       subroutine
            lda #0
            jsr wait
            dey
            bne delay
            rts

wait        sec
            SET_PAGE
.1          pha
.2          sbc #1
            bne .2
            pla
            sbc #1
            bne .1
            CHECK_PAGE
            rts

;-----------------------------------------------------------
;
; Returns a random 8-bit number in A (0-255), modifies Y (unknown)
; (from https://wiki.nesdev.com/w/index.php/Random_number_generator)
;   Assumes seed0 and seed1 zpage values have been initialized.
;   35 bytes, 69 cycles
;
random      subroutine

            lda seed1
            tay
            lsr
            lsr
            lsr
            sta seed1
            lsr
            eor seed1
            lsr
            eor seed1
            eor seed0
            sta seed1
            tya
            sta seed0
            asl
            eor seed0
            asl
            eor seed0
            asl
            asl
            asl
            eor seed0
            sta seed0
            rts

;-----------------------------------------------------------
