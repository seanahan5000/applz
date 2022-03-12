;
; on entry:
;   x: x position in bytes
;   y: y position in lines
;
set_text_xy stx xpos
            sty ypos
            rts
;
; on entry
;
;   x: string pointer low
;   y: string pointer high
;
draw_string subroutine

            stx textl
            sty texth
            ldy #0
            lda (textl),y
            sta text_length
            iny
.1          sty text_index
            lda (textl),y
            beq .2
            jsr draw_ascii_char
            ldy text_index
            cpy text_length
            beq .2
            iny
            bne .1          ; always
.2          rts
;
; on entry:
;   x: high 1 digit
;   a: low 2 digits
;
draw_digits3 subroutine
            pha
            txa
            and #$0f
            jsr draw_index_char
            pla
            pha
            lsr
            lsr
            lsr
            lsr
            jsr draw_index_char
            pla
            and #$0f
            bpl draw_index_char ; always

draw_ascii_char subroutine

            cmp #"0"
            bcc .1
            cmp #"9"+1
            bcs .1
            sec
            sbc #"0"
            bpl draw_index_char  ; always

.1          cmp #"A"
            bcc .2
            cmp #"Z"+1
            bcs .2
            sec
            sbc #"A"-11
            bpl draw_index_char  ; always

.2          cmp #" "
            bne .3
            lda #10
            bne draw_index_char  ; always

.3          ldx #14
.4          cmp ascii_table,x
            beq .5
            dex
            bpl .4
            inx
.5          txa
            clc
            adc #37

draw_index_char subroutine
            ldy #>font
            sta temp
            asl
            asl
            asl
            bcc .1
            iny
.1          clc
            adc #<font
            bcc .2
            iny
.2          sec
            sbc temp
            sta char_mod+1
            bcs .3
            dey
.3          sty char_mod+2

draw_char   ldx #0
            lda ypos
            sta ycount
char_loop   ldy ycount
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
char_mod    lda font,x
            ldy xpos
            sta (screenl),y
            inc ycount
            inx
            cpx #7
            bne char_loop
            inc xpos
            rts

font        dc.b %00011110      ; 0
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00001100      ; 1
            dc.b %00001110
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00011110

            dc.b %00011110      ; 2
            dc.b %00110011
            dc.b %00110000
            dc.b %00011100
            dc.b %00000110
            dc.b %00000011
            dc.b %00111111

            dc.b %00011110      ; 3
            dc.b %00110011
            dc.b %00110000
            dc.b %00011100
            dc.b %00110000
            dc.b %00110011
            dc.b %00011110

            dc.b %00110011      ; 4
            dc.b %00110011
            dc.b %00110011
            dc.b %00111111
            dc.b %00110000
            dc.b %00110000
            dc.b %00110000

            dc.b %00111111      ; 4
            dc.b %00000011
            dc.b %00000011
            dc.b %00011111
            dc.b %00110000
            dc.b %00110011
            dc.b %00011110

            dc.b %00011110      ; 6
            dc.b %00110011
            dc.b %00000011
            dc.b %00011111
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00111111      ; 7
            dc.b %00110000
            dc.b %00110000
            dc.b %00011000
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100

            dc.b %00011110      ; 8
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00011110      ; 9
            dc.b %00110011
            dc.b %00110011
            dc.b %00111110
            dc.b %00110000
            dc.b %00110011
            dc.b %00011110

            dc.b %00000000      ; <space>
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000

            dc.b %00011110      ; A
            dc.b %00110011
            dc.b %00110011
            dc.b %00111111
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011

            dc.b %00011111      ; B
            dc.b %00110011
            dc.b %00110011
            dc.b %00011111
            dc.b %00110011
            dc.b %00110011
            dc.b %00011111

            dc.b %00011110      ; C
            dc.b %00110011
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011
            dc.b %00110011
            dc.b %00011110

            dc.b %00011111      ; D
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011111

            dc.b %00111111      ; E
            dc.b %00110011
            dc.b %00000011
            dc.b %00001111
            dc.b %00000011
            dc.b %00110011
            dc.b %00111111

            dc.b %00111111      ; F
            dc.b %00110011
            dc.b %00000011
            dc.b %00001111
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011

            dc.b %00011110      ; G
            dc.b %00110011
            dc.b %00000011
            dc.b %00111011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00110011      ; H
            dc.b %00110011
            dc.b %00110011
            dc.b %00111111
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011

            dc.b %00011110      ; I
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00011110

            dc.b %00110000      ; J
            dc.b %00110000
            dc.b %00110000
            dc.b %00110000
            dc.b %00110000
            dc.b %00110011
            dc.b %00011110

            dc.b %00110011      ; K
            dc.b %00110011
            dc.b %00011011
            dc.b %00001111
            dc.b %00011011
            dc.b %00110011
            dc.b %00110011

            dc.b %00000011      ; L
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011
            dc.b %00111111

            dc.b %00110011      ; M
            dc.b %00111111
            dc.b %00111111
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011

            dc.b %00110011      ; N
            dc.b %00110111
            dc.b %00111111
            dc.b %00111111
            dc.b %00111011
            dc.b %00110011
            dc.b %00110011

            dc.b %00011110      ; O
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00011111      ; P
            dc.b %00110011
            dc.b %00110011
            dc.b %00011111
            dc.b %00000011
            dc.b %00000011
            dc.b %00000011

            dc.b %00011110      ; Q
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011011
            dc.b %00110110

            dc.b %00011111      ; R
            dc.b %00110011
            dc.b %00110011
            dc.b %00011111
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011

            dc.b %00011110      ; S
            dc.b %00110011
            dc.b %00000111
            dc.b %00011110
            dc.b %00111000
            dc.b %00110011
            dc.b %00011110

            dc.b %00111111      ; T
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100

            dc.b %00110011      ; U
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110

            dc.b %00110011      ; V
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110
            dc.b %00001100

            dc.b %00110011      ; W
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011
            dc.b %00111111
            dc.b %00111111
            dc.b %00110011

            dc.b %00110011      ; X
            dc.b %00110011
            dc.b %00110011
            dc.b %00011110
            dc.b %00110011
            dc.b %00110011
            dc.b %00110011

            dc.b %00110011      ; Y
            dc.b %00110011
            dc.b %00110011
            dc.b %00111110
            dc.b %00110000
            dc.b %00110011
            dc.b %00011110

            dc.b %00111111      ; Z
            dc.b %00110000
            dc.b %00011000
            dc.b %00001100
            dc.b %00000110
            dc.b %00000011
            dc.b %00111111

            dc.b %00001100      ; !
            dc.b %00001100
            dc.b %00001100
            dc.b %00001100
            dc.b %00000000
            dc.b %00001100
            dc.b %00001100

            dc.b %00110011      ; ""
            dc.b %00110011
            dc.b %00110011
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000

            dc.b %00110011      ; %
            dc.b %00110011
            dc.b %00011000
            dc.b %00001100
            dc.b %00000110
            dc.b %00110011
            dc.b %00110011

            dc.b %00001100      ; '
            dc.b %00001100
            dc.b %00001100
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000

            dc.b %00000000      ; *
            dc.b %00110011
            dc.b %00001100
            dc.b %00111111
            dc.b %00001100
            dc.b %00110011
            dc.b %00000000

            dc.b %00000000      ; +
            dc.b %00001100
            dc.b %00001100
            dc.b %00111111
            dc.b %00001100
            dc.b %00001100
            dc.b %00000000

            dc.b %00000000      ; ,
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00001100
            dc.b %00001100
            dc.b %00000110

            dc.b %00000000      ; -
            dc.b %00000000
            dc.b %00000000
            dc.b %00111111
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000

            dc.b %00000000      ; .
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00000000
            dc.b %00001100
            dc.b %00001100

            dc.b %00000000      ; /
            dc.b %00110000
            dc.b %00011000
            dc.b %00001100
            dc.b %00000110
            dc.b %00000011
            dc.b %00000000

            dc.b %00000000      ; :
            dc.b %00001100
            dc.b %00001100
            dc.b %00000000
            dc.b %00001100
            dc.b %00001100
            dc.b %00000000

            dc.b %00011000      ; <
            dc.b %00001100
            dc.b %00000110
            dc.b %00000011
            dc.b %00000110
            dc.b %00001100
            dc.b %00011000

            dc.b %00000000      ; =
            dc.b %00000000
            dc.b %00111111
            dc.b %00000000
            dc.b %00111111
            dc.b %00000000
            dc.b %00000000

            dc.b %00000110      ; >
            dc.b %00001100
            dc.b %00011000
            dc.b %00110000
            dc.b %00011000
            dc.b %00001100
            dc.b %00000110

            dc.b %00011110      ; ?
            dc.b %00110011
            dc.b %00011000
            dc.b %00001100
            dc.b %00000000
            dc.b %00001100
            dc.b %00001100

;ascii_table ASC #!"%'*+,-./:<=>?#
ascii_table dc.b "!!%'*+,-./:<=>?"
