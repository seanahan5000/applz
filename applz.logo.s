
sine_step   =   8
delay_step  =   4

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
            tay
            clc
            adc logo_heights,x
            sta .yend_mod+1
            ldx #0
.1          sty ypos
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
            bne .1
            rts

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
