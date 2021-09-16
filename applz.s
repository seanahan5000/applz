
; ./dasm applz.s -lapplz.lst -f3 -oapplz

            processor 6502

            mac assume
                if ({1})
                else
                    echo "Assumption failed: " {1}
                    err
                endif
            endm

double_speed = 1

block_type1  = 1
block_type2  = 2
block_width  = 21   ; including gap
block_height = 20   ; including gap
block_gap    = 2

ball_width  = 5
ball_height = 5
dot_height  = 3

grid_screen_left = 6    ; in bytes
grid_screen_top  = 0  ;***block_height
grid_width  = 9     ; includes left and right padding
grid_height = 10    ; includes bottom dead space
grid_size   = grid_width * grid_height
grid_screen_width = grid_width * 3 * 7  ;***  only used by dotz

wave_x      = 31
wave_y      = 20

throttle_ballz = 16     ; under this ball count, add delay

        if double_speed
send_delay  = 8
        else
send_delay  = 16
        endif

scroll_delta = 4        ; number of lines stepped per grid scroll

start_y     = 192 - ball_height

temp          = $00
xpos          = $01
ypos          = $02
ycount        = $03

textl         = $04
texth         = $05
text_index    = $06
text_length   = $07

; $10
applz_visible = $11     ; applz visible on screen (<= appl_slots)
appl_slots    = $12     ; slots used in tables, both visible and complete

appl_index    = $13
dot_count     = $14

angle         = $16
angle_dx_frac = $17
angle_dx_int  = $18
angle_dy_frac = $19
angle_dy_int  = $1a
button_up     = $1b     ; saw button up between unthrottle mode and aiming

start_x       = $1c     ; variable position relative to grid edge
send_countdown = $1d

appl_count  = $1f       ; total number of applz the player has collected

screenl     = $20
screenh     = $21
seed0       = $22
seed1       = $23

grid_left   = $30
grid_dx     = $31
grid_top    = $32
grid_col    = $33
grid_row    = $34

block_index = $35
block_type  = $36
block_color = $37
block_top   = $38
block_left  = $39
block_mid   = $3a
block_bot   = $3b

wave_index  = $40
wave_bcd0   = $41
wave_bcd1   = $42

applz_ready = $43       ; applz ready but not yet launched
applz_ready_bcd0 = $44
applz_ready_bcd1 = $45

; TODO: move these
ball_x      = $48
ball_dx     = $49
ball_y      = $4a
ball_dy     = $4b

x_frac      = $1000
x_int       = $1100
dx_frac     = $1200
dx_int      = $1300
y_frac      = $1400
y_int       = $1500
dy_frac     = $1600
dy_int      = $1700

; TODO: use correct abbreviations
keyboard    = $C000
unstrobe    = $C010
click       = $C030
graphics    = $C050
text        = $C051
fullscreen  = $C052
primary     = $C054
secondary   = $C055
hires       = $C057
pbutton0    = $C061

PREAD       = $FB1E

; TODO:
;   - ballz in grid w/animation
;   - game over detection
;   - real scoring/high score
;   - improved block emptying
;   - remove aiming richochet
;   - keyboard aiming support?

            org $6000

start
            ; init random number seed values

            lda #$12
            sta seed0
            lda #$34
            sta seed1

            lda #1
            sta wave_bcd0
            sta wave_index
            sta appl_count

            lda #0
            sta wave_bcd1

            jsr clear1
            jsr erase_screen_grid

            sta primary
            sta fullscreen
            sta hires
            sta graphics

            ; draw "wave:"

            ldx #wave_x
            ldy #wave_y
            jsr set_text_xy
            ldx #<wave_str
            ldy #>wave_str
            jsr draw_string

            lda #72         ; TODO: use a constant
            sta start_x

            jmp first_wave_mode

wave_str    dc.b 5,"WAVE:"

; TODO: move this code down lower in file
; TODO: nobody currently calls this

clear_grid  subroutine

            lda #grid_height
            sta grid_row
            lda #0
            tay
.1          iny
            ldx #grid_width-2
.2          sta block_grid,y
            sta block_counts,y
            iny
            dex
            bne .2
            iny
            dec grid_row
            bne .1
            rts

scroll_blocks subroutine

            ldy #grid_size-grid_width-1
.1          lda block_grid,y
            sta block_grid+grid_width,y
            lda block_counts,y
            sta block_counts+grid_width,y
            dey
            bpl .1

            ldy #grid_width-2
            lda #0
.2          sta block_grid,y
            sta block_counts,y
            dey
            bne .2
            rts

; TODO: page align
block_grid  dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            ; TODO: set -1 as part of clear
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1
            dc.b -1, 0, 0, 0, 0, 0, 0, 0,-1

block_counts
            ds grid_size,0

;=======================================
; Wave mode
;=======================================

; TODO: check for game over
;*** first time through, random number will always be the same

next_wave_mode subroutine
            ldx wave_index
            cpx #255            ; cap wave at 255
            bcs .1
            inx
            sed
            lda wave_bcd0
        ;   clc
            adc #1
            sta wave_bcd0
            lda wave_bcd1
            adc #0
            sta wave_bcd1
            cld
.1          stx wave_index
            stx appl_count      ; TODO: for now, bump applz along with wave

first_wave_mode subroutine

            ; draw wave number

            ldx #wave_x+5
            ldy #wave_y
            jsr set_text_xy
            lda wave_bcd1
            jsr draw_number
            lda wave_bcd0
            jsr draw_number

            ; get number of blocks to create, from 2 to 6

.1          jsr random
            tax
            lda mod7,x
            cmp #2
            bcc .1
            sta block_index

            ; create new blocks on top row, allowing at most one block double-up
            ;*** don't double up past 255 ***

.2          jsr random
            tax
            ldy mod7,x
            lda block_counts+1,Y
            beq .3
            cmp wave_index
            bcs .2
.3          clc
            adc wave_index
            sta block_counts+1,y
            lda #block_type1        ; TODO: pick block_type2
            sta block_grid+1,y
            dec block_index
            bne .2

            ; draw new blocks on top row

            ldy #1
.4          sty block_index
            lda block_grid,y
            beq .5
            jsr draw_block
            ldy block_index
.5          iny
            cpy #grid_width-1
            bne .4

            jsr scroll_blocks
            jsr scroll_screen_grid

            ; fall through

;=======================================
; Aiming mode
;=======================================

aiming_mode subroutine

            lda #16         ;*** dot count
            sta dot_count
            lda #0
            sta appl_index

            ; convert applz_ready to BCD and draw

            lda appl_count
            jsr set_applz_ready
            jsr draw_applz_ready

            lda #0
            sta x_frac
            sta y_frac
            ldx start_x
            stx x_int
            lda #start_y
            sta y_int
            jsr eor_appl        ; draw aiming ball

            lda #$80
            sta angle
            lda #0
            sta button_up

.loop1      jsr update_angle
            lda angle_dx_frac
            sta dx_frac
            lda angle_dx_int
            sta dx_int
            lda angle_dy_frac
            sta dy_frac
            lda angle_dy_int
            sta dy_int

            jsr draw_dotz

.loop2      ldx #1
            bit pbutton0        ; check for paddle 0 button press
            bpl .1
            ldx button_up       ; must have seen button up once in case
            bne running_mode    ;   unthrottled mode was being used coming in
.1          stx button_up

            ldx #0
            jsr PREAD           ; read paddle 0 value
            cpy #2              ; clamp value to [2,253]
            bcs .2              ;*** TODO: clamp a little more?
            ldy #2
.2          cpy #253
            bcc .3
            ldy #253
.3          cpy angle
            beq .loop2          ; loop until something changes
            sty angle

            jsr erase_dotz

            ;*** keep disabled while debugging
            ;jsr random          ; update random number on input change
            jmp .loop1

;=======================================
; Running mode
;=======================================

running_mode subroutine

            ldx x_int
            lda y_int
            jsr eor_appl        ; erase aiming ball
            jsr erase_dotz

            lda #send_delay
            sta send_countdown

            lda #0
            sta applz_visible
            sta appl_slots
            beq .first          ; always

            ; update and redraw visible applz

.loop1      ldx #0
.loop2      stx appl_index
            jsr update_appl
            ldx appl_index
            inx
            cpx appl_slots
            bne .loop2

            ; add delay for low ball counts
            ;   (~600 cycles per ball below throttle_ballz)

            bit pbutton0        ; check for paddle 0 button press
            bmi .nodelay
            lda #throttle_ballz
            sec
            sbc appl_slots
            bcc .nodelay
            beq .nodelay
            tax
.delay1     ldy #120             ; 120 * 5 cycles
.delay2     dey
            bne .delay2
            dex
            bne .delay1
.nodelay

            lda applz_ready     ; any applz left to send?
            bne .send
            lda applz_visible   ; any still visible?
            bne .loop1
            jmp next_wave_mode  ; no, start next wave

.send       dec send_countdown  ; check if it has been long enough to send
            bne .loop1

            lda #send_delay     ; reset send delay countdown
            sta send_countdown

.first      ldx appl_slots
            inc appl_slots

            lda start_x         ; set start position
            sta x_int,x
            lda #start_y
            sta y_int,x
            lda #0
            sta x_frac,x
            sta y_frac,x

            lda angle_dx_frac   ; set deltas based on angle
            sta dx_frac,x
            lda angle_dx_int
            sta dx_int,x
            lda angle_dy_frac
            sta dy_frac,x
            lda angle_dy_int
            sta dy_int,x

            stx appl_index

            ; decrement applz_ready count and update text

            dec applz_ready
            sed
            lda applz_ready_bcd0
            sec
            sbc #1
            sta applz_ready_bcd0
            lda applz_ready_bcd1
            sbc #0
            sta applz_ready_bcd1
            cld
            jsr draw_applz_ready

            inc applz_visible

            ldy appl_index
            ldx x_int,y
            lda y_int,y
            jsr eor_appl
            jmp .loop1

; set and convert applz_ready to BCD
;
; on entry:
;   a: applz_ready value

set_applz_ready subroutine

            sta applz_ready
            tax
            ldy #0
.1          txa
            sec
            sbc #100
            bcc .2
            tax
            iny
            bne .1              ; always
.2          sty applz_ready_bcd1

            ldy #0
.3          txa
            sec
            sbc #10
            bcc .4
            tax
            iny
            bne .3              ; always

.4          stx applz_ready_bcd0
            tya
            asl
            asl
            asl
            asl
            ora applz_ready_bcd0
            sta applz_ready_bcd0
            rts

draw_applz_ready
            ldx #wave_x+5
            ldy #wave_y+8
            jsr set_text_xy
            lda applz_ready_bcd1
            jsr draw_number
            lda applz_ready_bcd0
            jmp draw_number

;---------------------------------------

draw_dotz   subroutine

            ldx #1
.1          stx appl_index

            ; copy dx and dy from previous dot

            lda x_frac-1,x
            sta x_frac,x
            lda x_int-1,x
            sta x_int,x

            lda y_frac-1,x
            sta y_frac,x
            lda y_int-1,x
            sta y_int,x

            lda dx_frac-1,x
            sta dx_frac,x
            lda dx_int-1,x
            sta dx_int,x

            lda dy_frac-1,x
            sta dy_frac,x
            lda dy_int-1,x
            sta dy_int,x

            ; apply dx and dy multiple times

        if double_speed
            lda #4
        else
            lda #8
        endif
            sta grid_col            ;***
            ldx appl_index
.2          jsr update_dot
            dec grid_col
            bne .2

            jsr eor_dot

            ldx appl_index
            inx
            cpx dot_count
            bne .1
            rts


erase_dotz  subroutine

            ldx #1
.1          stx appl_index
            jsr eor_dot
            ldx appl_index
            inx
            cpx dot_count
            bne .1
            rts

;---------------------------------------
;
; update single dot position
;
; on entry:
;   x: appl_index
;
; on exit:
;   x: appl_index
;
update_dot  subroutine

            lda x_frac,x
            clc
            adc dx_frac,x
            sta x_frac,x
            lda x_int,x
            adc dx_int,x
            sta x_int,x

            ;*** get rid of ricochet
            cmp #21
            bcc .1
            cmp #grid_screen_width - 21 - ball_width
            bcc .2
.1          jsr reflect_x
.2
            lda y_frac,x
            clc
            adc dy_frac,x
            sta y_frac,x
            lda y_int,x
            adc dy_int,x
            sta y_int,x
            rts

;---------------------------------------
;
; remove ball off bottom of screen

ball_done   subroutine

            ldx ball_x
            lda ball_y
            jsr eor_appl

            ldx appl_index
            dec applz_visible
            bne .1
            lda applz_ready
            beq wave_done
.1
            ldy appl_slots
            dey
            sty appl_slots

            cpx appl_slots
            beq .2

            ; if completed ball is not in last slot,
            ;   move down ball in last slot to fill in gap

            lda x_frac,y
            sta x_frac,x
            lda x_int,y
            sta x_int,x
            lda dx_frac,y
            sta dx_frac,x
            lda dx_int,y
            sta dx_int,x
            lda y_frac,y
            sta y_frac,x
            lda y_int,y
            sta y_int,x
            lda dy_frac,y
            sta dy_frac,x
            lda dy_int,y
            sta dy_int,x

            ; moved ball becomes next to be processed

.2          dex
            stx appl_index
            rts

wave_done   subroutine

            lda x_int,x         ; use final x for start/aim x
            cmp #block_width    ;   clamped to reasonable values
            bcs .1
            lda #block_width
.1          cmp #162
            bcc .2
            lda #162            ; grid_screen_width - 21 - ball_width - 1
.2          sta start_x
            rts

;---------------------------------------
;
; update single appl position
;
; on entry:
;   x: appl_index
;
; on exit:
;   x: appl_index
;
; NOTE: Reflection code is optimized for fall through path
;   where all blocks are empty, since this is common case.
;

update_appl subroutine

            lda x_frac,x                                ; 4
            clc                                         ; 2
            adc dx_frac,x                               ; 4
            sta x_frac,x                                ; 4
            lda x_int,x                                 ; 4
            sta ball_x                                  ; 3
            adc dx_int,x                                ; 4
            sta x_int,x                                 ; 4
            sta ball_dx                                 ; 3
            tay                                         ; 2

            lda grid_x_table + 1,y                      ; 4
            sta grid_left                               ; 3
            sec                                         ; 2
            sbc grid_x_table + 1 + ball_width - 1,y     ; 4
            sta grid_dx                                 ; 3

            lda y_frac,x                                ; 4
            clc                                         ; 2
            adc dy_frac,x                               ; 4
            sta y_frac,x                                ; 4
            lda y_int,x                                 ; 4
            sta ball_y                                  ; 3
            adc dy_int,x                                ; 4
            sta y_int,x                                 ; 4

            cmp #192-ball_height                        ; 2     ; check for ball y wrapping
            bcs .reverse_dy                             ; 2

.post_reverse_d7
            sta ball_dy                                 ; 3
            tay                                         ; 2

            lda grid_y_table + block_gap,y              ; 4
            sta grid_top                                ; 3
            cmp grid_y_table + ball_height - 1,y        ; 4
            bne up_down                                 ; 2     ; crossed horizontal block edge
            lda grid_dx                                 ; 3
            bne left_right_y1                           ; 2     ; crossed vertical block edge
            jmp move_appl                               ; 4     ; TODO: get rid of
                                                        ; = 110
; reflect ball at top of screen

.reverse_dy cmp #192+ball_height+1
            bcc .ball_done
            jsr reflect_y
            jmp .post_reverse_d7
.ball_done  jmp ball_done

;
; ball moving vertically crossed horizontal edge on single block
;
;   +-+   O
;   | |  +O+
;   +O+  | |
;    O   +-+
;
up_down     lda grid_dx
            bne left_right_y2
up_down_x1  lda grid_left
            clc
            adc grid_top
            tay
            lda dy_int,x
            bpl .down

.up         lda block_grid,y
            bne .bounce_dy
            jmp move_appl       ; TODO: get rid of

.down       lda block_grid+grid_width,y
            bne .next_y_bounce_dy
            jmp move_appl       ; TODO: get rid of

.next_y_bounce_dy
            tya
            clc
            adc #grid_width
            tay
.bounce_dy  jsr reflect_y
            jmp hit_move_appl   ; TODO: get rid of

;
; ball moving horizontally crossed vertical edge on single block
;
;   +-+   +-+
;  OO |   | OO
;   +-+   +-+
;
left_right_y1
            lda grid_left
            clc
            adc grid_top
            tay
            lda dx_int,x        ; moving left or right?
            bmi .left
            iny                 ; look at right edge
.left       lda block_grid,y
            bne .bounce_dx
            jmp move_appl       ; TODO: get rid of

.bounce_dx  jsr reflect_x
            jmp hit_move_appl   ; TODO: get rid of
;
; ball moving horizontally crossed vertical edge on two blocks
;
left_right_y2
            lda grid_left
            clc
            adc grid_top
            tay
            lda dy_int,x
            bmi diag_up
            jmp diag_down

diag_up     lda dx_int,x
            bmi diag_up_left
;
;   a      b      c      d      e      f      g
; +-+      +-+                +-+-+    +-+  +-+..
; | |      | |                | | |    | |  | | .
; +-O      O-+           O-+  +-O-+    O-+  +-O-+
;  O      O             O| |   O      O| |   O| |
;                        +-+           +-+    +-+
;
diag_up_right subroutine

            lda block_grid+grid_width+1,y
            bne .dfg
            lda block_grid,y
            bne .ae
            lda block_grid+1,y
            bne .b
            jmp move_appl_ur

.ae         lda block_grid+1,y
            bne .e

.a          jsr reflect_y
            jmp hit_move_appl_dr

.e          jsr reflect_y
            jsr hit_block
            iny
            jmp hit_move_appl_dr

.b          iny
            jsr reflect_y
            jsr reflect_x
            jmp hit_no_move

.dfg        lda block_grid,y
            bne .g
            lda block_grid+1,y
            bne .f

.d          jsr reflect_x
            tya
            clc
            adc #grid_width+1
            tay
            jmp hit_move_appl_ul

.f          iny
            jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_ul

.g          jsr reflect_y
            jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width+1
            tay
            jmp hit_no_move

;
;   a      b       c     d      e      f      g
; +-+      +-+                +-+-+  +-+    ..+-+
; | |      | |                | | |  | |    . | |
; +-O      O-+   +-O          +-O-+  +-O    +-O-+
;    O      O    | |O            O   | |O   | |O
;                +-+                 +-+    +-+
;
diag_up_left subroutine

            lda block_grid+grid_width,y
            bne .cfg
            lda block_grid+1,y
            bne .be
            lda block_grid,y
            bne .a
            jmp move_appl_ul

.be         lda block_grid,y
            bne .e

.b          iny
            jsr reflect_y
            jmp hit_move_appl_dl

.e          jsr reflect_y
            jsr hit_block
            iny
            jmp hit_move_appl_dl

.a          jsr reflect_y
            jsr reflect_x
            jmp hit_no_move

.cfg        lda block_grid+1,y
            bne .g
.cf         lda block_grid,y
            bne .f

.c          jsr reflect_x
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_ur

.f          jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_ur

.g          jsr reflect_y
            jsr reflect_x
            iny
            jsr hit_block
            tya
            clc
            adc #grid_width-1
            tay
            jmp hit_no_move

diag_down   lda dx_int,x
            bmi diag_down_left
;
;   a      b       c     d      e      f      g
;          +-+                         +-+    +-+
;         O| |    O     O      O      O| |   O| |
;          O-+   +-O     O-+  +-O-+    O-+  +-O-+
;                | |     | |  | | |    | |  | | .
;                +-+     +-+  +-+-+    +-+  +-+..
;
diag_down_right subroutine

            lda block_grid+1,y
            bne .bfg
            lda block_grid+grid_width,y
            bne .ce
            lda block_grid+grid_width+1,y
            bne .d
            jmp move_appl_dr

.ce         lda block_grid+grid_width+1,y
            bne .e

.c          jsr reflect_y
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_ur

.e          jsr reflect_y
            tya
            clc
            adc #grid_width
            tay
            jsr hit_block
            iny
            jmp hit_move_appl_ur

.d          jsr reflect_y
            jsr reflect_x
            tya
            clc
            adc #grid_width+1
            tay
            jmp hit_no_move

.bfg        lda block_grid+grid_width,y
            bne .g
.bf         lda block_grid+grid_width+1,y
            bne .f

.b          iny
            jsr reflect_x
            jmp hit_move_appl_dl

.f          iny
            jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_dl

.g          jsr reflect_y
            jsr reflect_x
            iny
            jsr hit_block
            tya
            clc
            adc #grid_width-1
            tay
            jmp hit_no_move

;
;   a      b       c     d      e      f      g
; +-+                                +-+    +-+
; | |O              O     O      O   | |O   | |O
; +-O            +-O     O-+  +-O-+  +-O    +-O-+
;                | |     | |  | | |  | |    . | |
;                +-+     +-+  +-+-+  +-+    ..+-+
;
diag_down_left subroutine

            lda block_grid,y
            bne .afg
            lda block_grid+grid_width+1,y
            bne .de
            lda block_grid+grid_width,y
            bne .c
            jmp move_appl_dl

.de         lda block_grid+grid_width,y
            bne .e

.d          jsr reflect_y
            tya
            clc
            adc #grid_width+1
            tay
            jmp hit_move_appl_ul

.e          jsr reflect_y
            tya
            clc
            adc #grid_width
            tay
            jsr hit_block
            iny
            jmp hit_move_appl_ul

.c          jsr reflect_y
            jsr reflect_x
            tya
            clc
            adc #grid_width
            tay
            jmp hit_no_move

.afg        lda block_grid+grid_width+1,y
            bne .g
.af         lda block_grid+grid_width,y
            bne .f

.a          jsr reflect_x
            jmp hit_move_appl_dr

.f          jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width
            tay
            jmp hit_move_appl_dr

.g          jsr reflect_y
            jsr reflect_x
            jsr hit_block
            tya
            clc
            adc #grid_width+1
            tay
            jmp hit_no_move

;
; reflect x/y,dx/dy without altering block counts
;
; on entry:
;   x: ball index
;   y: block index
;
; on exit:
;   x: ball index
;   y: block index
;

reflect_x   lda x_frac,x        ; back up to old x
            sec
            sbc dx_frac,x
            sta x_frac,x
            lda x_int,x
            sbc dx_int,x
            sta x_int,x
            sta ball_x
            sta ball_dx

            lda dx_frac,x       ; negate dx
            eor #$ff
            clc
            adc #1
            sta dx_frac,x
            lda dx_int,x
            eor #$ff
            adc #0
            sta dx_int,x
            rts

reflect_y   lda y_frac,x        ; back up to old y
            sec
            sbc dy_frac,x
            sta y_frac,x
            lda y_int,x
            sbc dy_int,x
            sta y_int,x
            sta ball_y
            sta ball_dy

            lda dy_frac,x       ; negate dy
            eor #$ff
            clc
            adc #1
            sta dy_frac,x
            lda dy_int,x
            eor #$ff
            adc #0
            sta dy_int,x

            ;*** caller assumes ball_dy in A
            lda ball_dy
            rts

;
; handle hitting block
;
; on entry:
;   x: ball index
;   y: block index
;
; on exit:
;   x: ball index
;   y: block index
;
hit_block   subroutine

            lda block_counts,y
            beq .1              ; border blocks have zero count
            sec
            sbc #1
            sta block_counts,y
            bne .2

            lda #0
            sta block_grid,y
            sty block_index
            jsr erase_block
            ldx appl_index      ; restore ball index
            ldy block_index     ; restore block index
.1          rts

.2          lda block_grid,y
            sty block_index
            jsr draw_block
            ldx appl_index      ; restore ball index
            ldy block_index     ; restore block index
            rts

; divide by 21 table to convert x position into grid column
; (page aligned so table look-ups don't cost extra cycle for crossing page boundary)
            align 256
grid_x_table
            ds  block_width,0
            ds  block_width,1
            ds  block_width,2
            ds  block_width,3
            ds  block_width,4
            ds  block_width,5
            ds  block_width,6
            ds  block_width,7
            ds  block_width,8
            ;*** 0 instead? ***

; divide by 20 * grid_width table to convert y position into grid row offset
; (page aligned so table look-ups don't cost extra cycle for crossing page boundary)
            align 256
grid_y_table
            ds  block_height,0*grid_width
            ds  block_height,1*grid_width
            ds  block_height,2*grid_width
            ds  block_height,3*grid_width
            ds  block_height,4*grid_width
            ds  block_height,5*grid_width
            ds  block_height,6*grid_width
            ds  block_height,7*grid_width
            ds  block_height,8*grid_width
            ds  block_height,9*grid_width
            ds  block_height,10*grid_width
            ;*** 0*9 instead? ***

;---------------------------------------
;
; scroll all visible grid blocks down by one on screen
;
scroll_screen_grid subroutine

            lda #block_height/scroll_delta
            sta grid_row
.1          ldx #191
.2          lda hires_table_lo-scroll_delta,x
            clc
            adc #grid_screen_left+3
            sta .mod1+1
            lda hires_table_hi-scroll_delta,x
            sta .mod1+2

            lda hires_table_lo,x
        ;   clc
            adc #grid_screen_left+3
            sta .mod2+1
            lda hires_table_hi,x
            sta .mod2+2

            ldy #(grid_width-2)*3-1
.mod1       lda $ffff,y
.mod2       sta $ffff,y
            dey
            bpl .mod1

            dex
            cpx #scroll_delta-1
            bne .2

.3          lda hires_table_lo,x
            clc
            adc #grid_screen_left+3
            sta .mod3+1
            lda hires_table_hi,x
            sta .mod3+2
            ldy #(grid_width-2)*3-1
            lda #0
.mod3       sta $ffff,y
            dey
            bpl .mod3
            dex
            bpl .3

            dec grid_row
            bne .1
            rts

erase_screen_grid subroutine

            ldx #0
.1          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh

            ; draw bar on left of grid

            ldy #grid_screen_left+2
            lda #$18
            sta (screenl),y
            iny

            ; clear main grid

            lda #0
.2          sta (screenl),y
            iny
            cpy #grid_width*3-3+grid_screen_left
            bne .2

            ; draw bar on right of grid

            lda #$03
            sta (screenl),y

            inx
            cpx #192
            bne .1
            rts

;---------------------------------------
;
; entry
;   a: angle 0 (full left) to 255 (full right)
;
; NOTE: shortcut (ones-complement) negation being used
;
update_angle subroutine

            lda angle
            tax
            bpl .left

.right      and #$7f
            tax
            eor #$7f
            tay

        if double_speed
            lda sine_table,x
            asl
            sta angle_dx_frac
            lda #0
            rol
            sta angle_dx_int

            lda sine_table,y
            eor #$ff
            asl
            sta angle_dy_frac
            lda #$ff
            rol
            sta angle_dy_int
        else
            lda sine_table,x
            sta angle_dx_frac
            lda #0
            sta angle_dx_int

            lda sine_table,y
            eor #$ff
            sta angle_dy_frac
            lda #$ff
            sta angle_dy_int
        endif
            rts

.left       eor #$7f
            tay

        if double_speed
            lda sine_table,y
            eor #$ff
            asl
            sta angle_dx_frac
            lda #$ff
            rol
            sta angle_dx_int

            lda sine_table,x
            eor #$ff
            asl
            sta angle_dy_frac
            lda #$ff
            rol
            sta angle_dy_int
        else
            lda sine_table,y
            eor #$ff
            sta angle_dx_frac
            lda #$ff
            sta angle_dx_int

            lda sine_table,x
            eor #$ff
            sta angle_dy_frac
            lda #$ff
            sta angle_dy_int
        endif
            rts

;
; 128 sine values from [0, PI / 2)
;
;   for (uint32_t i = 0; i < 128; ++i)
;       value = (uint8_t)(sin(M_PI / 2 * i / 128) * 256);
;
sine_table  hex 000306090c0f1215
            hex 191c1f2225282b2e
            hex 3135383b3e414447
            hex 4a4d505356595c5f
            hex 6164676a6d707375
            hex 787b7e808386888b
            hex 8e909395989b9d9f
            hex a2a4a7a9abaeb0b2
            hex b5b7b9bbbdbfc1c3
            hex c5c7c9cbcdcfd1d3
            hex d4d6d8d9dbdddee0
            hex e1e3e4e6e7e8eaeb
            hex ecedeeeff1f2f3f4
            hex f4f5f6f7f8f9f9fa
            hex fbfbfcfcfdfdfefe
            hex feffffffffffffff

;
; on entry
;   y: grid index of block
;   a: block type
;
; TODO: don't draw if block level doesn't change
;
draw_block  subroutine

            ; choose color based on block type
;           ldx #$d5
;           cmp #block_type2
;           bne .1
            ldx #$55
.1          stx block_color

            lda grid_screen_rows,y
            tax
            clc
            adc #block_height-block_gap-1
            sta block_bot

            lda #block_height-block_gap
            sec
            sbc block_counts,y
            beq .2
            bcs .3
.2          lda #1
.3          clc
            adc grid_screen_rows,y
            sta block_mid

            lda grid_screen_cols,y
            tay

            ; first line

            lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda block_color
            sta (screenl),y
            iny
            eor #$7f
            sta (screenl),y
            iny
            lda (screenl),y
            eor block_color
            and #$60            ; clip out block gap
            eor block_color
            sta (screenl),y
            dey
            dey
            bpl .5              ; always

            ; draw empty box lines

.4          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda block_color
            and #$83
            sta (screenl),y
            iny
            and #$80
            sta (screenl),y
            iny
            lda (screenl),y
            eor block_color
            and #$60
            eor block_color
            and #$f8            ; clip out block gap
            sta (screenl),y
            dey
            dey
.5          inx
            cpx block_mid
            bne .4
            beq .7              ; always

            ; draw full box lines

.6          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda block_color
            sta (screenl),y
            iny
            eor #$7f
            sta (screenl),y
            iny
            lda (screenl),y
            eor block_color
            and #$60            ; clip out block gap
            eor block_color
            sta (screenl),y
            dey
            dey
            inx
.7          cpx block_bot
            bne .6

            ; last line

            lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda block_color
            sta (screenl),y
            iny
            eor #$7f
            sta (screenl),y
            iny
            lda (screenl),y
            eor block_color
            and #$60            ; clip out block gap
            eor block_color
            sta (screenl),y

            rts


            ; block pattern, reversed
            ; TODO: use this?

            dc.b %01010101, %00101010, %00010101     ; filled line (8/8)
            dc.b %01010001, %00101010, %00010101     ;             (7/8)
            dc.b %01000001, %00101010, %00010101     ;             (6/8)
            dc.b %00000001, %00101010, %00010101     ;             (5/8)

            dc.b %00000001, %00101000, %00010101     ;             (4/8)
            dc.b %00000001, %00100000, %00010101     ;             (3/8)
            dc.b %00000001, %00000000, %00010101     ;             (2/8)

            dc.b %00000001, %00000000, %00010100     ;             (1/8)
            dc.b %00000001, %00000000, %00010000     ; empty line  (0/8)

;
; on entry
;   y: grid index of block
;
erase_block subroutine

            lda grid_screen_rows,y
            tax
            clc
            adc #block_height-block_gap
            sta block_bot
            lda grid_screen_cols,y
            tay
.1          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda #0
            sta (screenl),y
            iny
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60
            sta (screenl),y
            dey
            dey
            inx
            cpx block_bot
            bne .1
            rts

            assume grid_height=10
            assume block_height=20
            assume grid_screen_top=0

grid_screen_rows
            ds  grid_width,0
            ds  grid_width,20
            ds  grid_width,40
            ds  grid_width,60
            ds  grid_width,80
            ds  grid_width,100
            ds  grid_width,120
            ds  grid_width,140
            ds  grid_width,160
            ds  grid_width,180

            assume grid_screen_left=6
            assume block_width=21

grid_screen_cols
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
            dc.b 6,9,12,15,18,21,24,27,30
;
; eor the dot shape
;
eor_dot     subroutine

            ldy appl_index
            ldx x_int,y
            lda y_int,y
            sta ypos
            lda div7,x
            clc
            adc #grid_screen_left
            sta xpos
            lda #dot_height
            sta ycount
            ldy mod7,x
            ldx dotz_lo,y
.1          ldy ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy xpos
            lda dot0,x
            eor (screenl),y
            sta (screenl),y
            inx
            iny
            lda dot0,x
            beq .2
            eor (screenl),y
            sta (screenl),y
.2          inx
            inc ypos
            dec ycount
            bne .1
            rts

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

; TODO: temporary, to be phased out as callers are cleaned up

hit_move_appl subroutine

            jsr hit_block

move_appl   subroutine

            lda ball_dy             ; 3
            cmp ball_y              ; 3
            bcc .up                 ; 2/3
            jmp move_down

.up         lda ball_dx             ; 3
            cmp ball_x              ; 3
            bcs move_appl_ur        ; 2/3
            bcc move_appl_ul        ; 3 always

; TODO: this may eventually call back into main appl update look
hit_no_move jmp hit_block

; eor move:
;
;   67 * 7 + 93 = 474 + 93 = 567
;   67 * 6 + 93 = 407 + 93 = 500
;   67 * 5 + 93 = 340 + 93 = 433
;
; simple erase/draw:
;
;   373 * 2 = 746

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

hit_move_appl_ul subroutine

            jsr hit_block

move_appl_ul subroutine

            lda ball_x              ; 3
            sec                     ; 2
            sbc ball_dx             ; 3
            asl                     ; 2
            asl                     ; 2
        ;   clc
            adc ball_y              ; 3
            sec                     ; 2
            sbc ball_dy             ; 3
            beq .exit               ; 2/3
            asl                     ; 2

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_dy             ; 3     y/dy
        ;   clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_dx             ; 3     x/dx
            lda div7,y              ; 4
        ;   clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
        ;   clc
            adc mod7,y              ; 4
            tax                     ; 2

            lda applz_lo,x          ; 4
            sta .mod1+1             ; 4
            sta .mod2+1             ; 4

            lda applz_hi,x          ; 4
            sta .mod1+2             ; 4
            sta .mod2+2             ; 4

            ldx #0                  ; 2
            ldy ball_dy             ; 3     y/dy
                                    ; = 93

.loop       lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy ball_x              ; 3
.mod1       lda $ffff,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
.mod2       lda $ffff,x             ; 4
            beq .skip0              ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
.skip0      inx                     ; 2
            ldy ball_dy             ; 3     y/dy
            iny                     ; 2
            sty ball_dy             ; 3     y/dy
            cpy ycount              ; 3
            bne .loop               ; 3/2
                                    ; = 67 (340/407/474)
.exit       rts                     ; 6

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

hit_move_appl_ur subroutine

            jsr hit_block

move_appl_ur subroutine

            lda ball_dx             ; 3
            sec                     ; 2
            sbc ball_x              ; 3
            asl                     ; 2
            asl                     ; 2
        ;   clc
            adc ball_y              ; 3
            sec                     ; 2
            sbc ball_dy             ; 3
            beq .exit               ; 2/3
            asl                     ; 2
        ;   clc
            adc #1                  ; 3

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_dy             ; 3     y/dy
        ;   clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_x              ; 3     x/dx
            lda div7,y              ; 4
        ;   clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
        ;   clc
            adc mod7,y              ; 4
            tax                     ; 2

            lda applz_lo,x          ; 4
            sta .mod1+1             ; 4
            sta .mod2+1             ; 4

            lda applz_hi,x          ; 4
            sta .mod1+2             ; 4
            sta .mod2+2             ; 4

            ldx #0                  ; 2
            ldy ball_dy             ; 3     y/dy
                                    ; = 96

.loop       lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy ball_x              ; 3
.mod1       lda $ffff,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
.mod2       lda $ffff,x             ; 4
            beq .skip0              ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
.skip0      inx                     ; 2
            ldy ball_dy             ; 3     y/dy
            iny                     ; 2
            sty ball_dy             ; 3     y/dy
            cpy ycount              ; 3
            bne .loop               ; 3/2
                                    ; = 67 (340/407/474)
.exit       rts                     ; 6

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

; TODO: temporary, to be phased out as callers are cleaned up
move_down   lda ball_dx             ; 3
            cmp ball_x              ; 3
            bcs move_appl_dr        ; 2/3
            bcc move_appl_dl        ; 3 always

hit_move_appl_dl subroutine

            jsr hit_block

move_appl_dl subroutine

            lda ball_x              ; 3     ((dx * 4) + dy) * 2 + ur_dl
            sec                     ; 2
            sbc ball_dx             ; 3
            asl                     ; 2
            asl                     ; 2
        ;   clc
            adc ball_dy             ; 3
            sec                     ; 2
            sbc ball_y              ; 3
            beq .exit               ; 2/3   no movement
            asl                     ; 2
        ;   clc
            adc #1                  ; 3     + ur_dl

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_y              ; 3     y/dy
        ;   clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_dx             ; 3     x/dx
            lda div7,y              ; 4
        ;   clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
        ;   clc
            adc mod7,y              ; 4
            tax                     ; 2

            lda applz_lo,x          ; 4
            sta .mod1+1             ; 4
            sta .mod2+1             ; 4

            lda applz_hi,x          ; 4
            sta .mod1+2             ; 4
            sta .mod2+2             ; 4

            ldx #0                  ; 2
            ldy ball_y              ; 3     y/dy
                                    ; = 96

.loop       lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy ball_x              ; 3
.mod1       lda $ffff,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
.mod2       lda $ffff,x             ; 4
            beq .skip0              ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
.skip0      inx                     ; 2
            ldy ball_y              ; 3     y/dy
            iny                     ; 2
            sty ball_y              ; 3     y/dy
            cpy ycount              ; 3
            bne .loop               ; 3/2
                                    ; = 67 (340/407/474)
.exit       rts                     ; 6

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

hit_move_appl_dr subroutine

            jsr hit_block

move_appl_dr subroutine

            lda ball_dx             ; 3     ((dx * 4) + dy) * 2
            sec                     ; 2
            sbc ball_x              ; 3
            asl                     ; 2
            asl                     ; 2
        ;   clc
            adc ball_dy             ; 3
            sec                     ; 2
            sbc ball_y              ; 3
            beq .exit               ; 2/3
            asl                     ; 2

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_y              ; 3     y/dy
        ;   clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_x              ; 3     x/dx
            lda div7,y              ; 4
        ;   clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
        ;   clc
            adc mod7,y              ; 4
            tax                     ; 2

            lda applz_lo,x          ; 4
            sta .mod1+1             ; 4
            sta .mod2+1             ; 4

            lda applz_hi,x          ; 4
            sta .mod1+2             ; 4
            sta .mod2+2             ; 4

            ldx #0                  ; 2
            ldy ball_y              ; 3     y/dy
                                    ; = 93

.loop       lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy ball_x              ; 3
.mod1       lda $ffff,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
.mod2       lda $ffff,x             ; 4
            beq .skip0              ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
.skip0      inx                     ; 2
            ldy ball_y              ; 3     y/dy
            iny                     ; 2
            sty ball_y              ; 3     y/dy
            cpy ycount              ; 3
            bne .loop               ; 3/2
                                    ; = 67 (340/407/474)
.exit       rts                     ; 6

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

;
; on entry:
;   X: x coordinate
;   A: y coordinate
;
eor_appl    subroutine

            sta ball_y
            clc
            adc #ball_height
            sta ycount

            lda div7,x
        ;   clc
            adc #grid_screen_left
            sta ball_x

            ldy mod7,x

            lda applz_lo,y
            sta .mod1+1
            sta .mod2+1

            lda applz_hi,y
            sta .mod1+2
            sta .mod2+2

            ldx #0
            ldy ball_y
.loop       lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy ball_x              ; 3
.mod1       lda $ffff,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
.mod2       lda $ffff,x             ; 4
            beq .skip0              ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
.skip0      inx                     ; 2
            ldy ball_y              ; 3
            iny                     ; 2
            sty ball_y              ; 3
            cpy ycount              ; 3
            bne .loop               ; 3/2
.exit       rts

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

; Returns a random 8-bit number in A (0-255), modifies Y (unknown)
; (from https://wiki.nesdev.com/w/index.php/Random_number_generator)
;   Assumes seed0 and seed1 zpage values have been initialized.
;   35 bytes, 69 cycles

random      lda seed1
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

;
; clear primary screen to black
;
clear1      subroutine

            ldx #0
            txa
.1          sta $2000,x
            sta $2100,x
            sta $2200,x
            sta $2300,x
            sta $2400,x
            sta $2500,x
            sta $2600,x
            sta $2700,x
            sta $2800,x
            sta $2900,x
            sta $2a00,x
            sta $2b00,x
            sta $2c00,x
            sta $2d00,x
            sta $2e00,x
            sta $2f00,x
            sta $3000,x
            sta $3100,x
            sta $3200,x
            sta $3300,x
            sta $3400,x
            sta $3500,x
            sta $3600,x
            sta $3700,x
            sta $3800,x
            sta $3900,x
            sta $3a00,x
            sta $3b00,x
            sta $3c00,x
            sta $3d00,x
            sta $3e00,x
            sta $3f00,x
            inx
            bne .1
            rts

dotz_lo     dc.b #<dot0
            dc.b #<dot1
            dc.b #<dot2
            dc.b #<dot3
            dc.b #<dot4
            dc.b #<dot5
            dc.b #<dot6

            align 256

dot0        dc.b %00000000, %00000000
            dc.b %00001100, %00000000
            dc.b %00001100, %00000000

dot1        dc.b %00000000, %00000000
            dc.b %00011000, %00000000
            dc.b %00011000, %00000000

dot2        dc.b %00000000, %00000000
            dc.b %00110000, %00000000
            dc.b %00110000, %00000000

dot3        dc.b %00000000, %00000000
            dc.b %01100000, %00000000
            dc.b %01100000, %00000000

dot4        dc.b %00000000, %00000000
            dc.b %01000000, %00000001
            dc.b %01000000, %00000001

dot5        dc.b %00000000, %00000000
            dc.b %00000000, %00000011
            dc.b %00000000, %00000011

dot6        dc.b %00000000, %00000000
            dc.b %00000000, %00000110
            dc.b %00000000, %00000110

            align 256

div7        hex 00000000000000
            hex 01010101010101
            hex 02020202020202
            hex 03030303030303
            hex 04040404040404
            hex 05050505050505
            hex 06060606060606
            hex 07070707070707
            hex 08080808080808
            hex 09090909090909
            hex 0a0a0a0a0a0a0a
            hex 0b0b0b0b0b0b0b
            hex 0c0c0c0c0c0c0c
            hex 0d0d0d0d0d0d0d
            hex 0e0e0e0e0e0e0e
            hex 0f0f0f0f0f0f0f
            hex 10101010101010
            hex 11111111111111
            hex 12121212121212
            hex 13131313131313
            hex 14141414141414
            hex 15151515151515
            hex 16161616161616
            hex 17171717171717
            hex 18181818181818
            hex 19191919191919
            hex 1a1a1a1a1a1a1a
            hex 1b1b1b1b1b1b1b
            hex 1c1c1c1c1c1c1c
            hex 1d1d1d1d1d1d1d
            hex 1e1e1e1e1e1e1e
            hex 1f1f1f1f1f1f1f
            hex 20202020202020
            hex 21212121212121
            hex 22222222222222
            hex 23232323232323
            hex 24242424

            align 256

mod7        hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203040506
            hex 00010203

            align 256

hires_table_lo
            hex 0000000000000000
            hex 8080808080808080
            hex 0000000000000000
            hex 8080808080808080
            hex 0000000000000000
            hex 8080808080808080
            hex 0000000000000000
            hex 8080808080808080
            hex 2828282828282828
            hex a8a8a8a8a8a8a8a8
            hex 2828282828282828
            hex a8a8a8a8a8a8a8a8
            hex 2828282828282828
            hex a8a8a8a8a8a8a8a8
            hex 2828282828282828
            hex a8a8a8a8a8a8a8a8
            hex 5050505050505050
            hex d0d0d0d0d0d0d0d0
            hex 5050505050505050
            hex d0d0d0d0d0d0d0d0
            hex 5050505050505050
            hex d0d0d0d0d0d0d0d0
            hex 5050505050505050
            hex d0d0d0d0d0d0d0d0

            align 256

hires_table_hi
            hex 2024282c3034383c
            hex 2024282c3034383c
            hex 2125292d3135393d
            hex 2125292d3135393d
            hex 22262a2e32363a3e
            hex 22262a2e32363a3e
            hex 23272b2f33373b3f
            hex 23272b2f33373b3f
            hex 2024282c3034383c
            hex 2024282c3034383c
            hex 2125292d3135393d
            hex 2125292d3135393d
            hex 22262a2e32363a3e
            hex 22262a2e32363a3e
            hex 23272b2f33373b3f
            hex 23272b2f33373b3f
            hex 2024282c3034383c
            hex 2024282c3034383c
            hex 2125292d3135393d
            hex 2125292d3135393d
            hex 22262a2e32363a3e
            hex 22262a2e32363a3e
            hex 23272b2f33373b3f
            hex 23272b2f33373b3f

            include applz.data.s
            include text.s

