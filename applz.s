
; ./dasm applz.s -lapplz.lst -f3 -oapplz

            processor 6502

            mac assume
                if ({1})
                else
                    echo "Assumption failed: " {1}
                    err
                endif
            endm

; constants

block_type_appl     = $01
block_type_edge     = $80
block_type_square   = $81

block_width         = 21    ; including gap
block_height        = 20    ; including gap
block_gap           = 2
block_height_nogap  = block_height-block_gap

ball_width          = 5
ball_height         = 5
dot_height          = 3

grid_screen_left    = 6     ; in bytes
grid_screen_top     = 4     ; implicit dependencies
grid_width          = 9     ; includes left and right padding
grid_height         = 10    ; includes bottom dead space
grid_size           = grid_width*grid_height
grid_screen_width   = grid_width*3*7
grid_border_height  = 2

max_aim_dots        = 32

wave_x              = 31    ; in bytes
wave_y              = 20
high_x              = wave_x
high_y              = wave_y+9

throttle_ballz      = 16    ; under this ball count, add delay

send_delay          = 8

scroll_delta        = 4     ; number of lines stepped per grid scroll

default_start_x     = 92
default_start_y     = 192-ball_height-8

min_angle           = 6
max_angle           = 255-min_angle

text_height         = 7     ; excluding line gaps

; zero page variables

temp            = $00
xpos            = $01
ypos            = $02
ycount          = $03

textl           = $04
texth           = $05
text_index      = $06
text_length     = $07

input_mode      = $10   ; 0: keyboard, 1: paddle
difficulty      = $11
applz_visible   = $12   ; applz visible on screen (<= appl_slots)
appl_slots      = $13   ; slots used in tables, both visible and complete

appl_index      = $14

dot_count       = $15
dot_repeat      = $16

angle           = $17
angle_dx_frac   = $18
angle_dx_int    = $19
angle_dy_frac   = $1a
angle_dy_int    = $1b
button_up       = $1c   ; saw button up between unthrottle mode and aiming

start_x         = $1d   ; variable position relative to grid edge
send_countdown  = $1e

appl_count      = $1f   ; total number of applz the player has collected

screenl         = $20
screenh         = $21
seed0           = $22
seed1           = $23

ball_x          = $28
ball_dx         = $29
ball_y          = $2a
ball_dy         = $2b
max_ball_y      = $2c

grid_left       = $30
grid_dx         = $31
grid_top        = $32
grid_col        = $33
grid_row        = $34

block_index     = $35
block_type      = $36
block_color     = $37
block_top       = $38
block_left      = $39
block_mid       = $3a
block_bot       = $3b

wave_index      = $40
wave_bcd0       = $41
wave_bcd1       = $42
wave_mag        = $43

high_index      = $44
high_bcd0       = $45
high_bcd1       = $46

applz_ready     = $47   ; applz ready but not yet launched
applz_ready_bcd0 = $48
applz_ready_bcd1 = $49

; buffer addresses

x_frac          = $1000
x_int           = $1100
dx_frac         = $1200
dx_int          = $1300
y_frac          = $1400
y_int           = $1500
dy_frac         = $1600
dy_int          = $1700

block_grid      = $1800 ; grid_size bytes used
block_counts    = $1880 ; grid_size bytes used

; TODO: use correct abbreviations
keyboard        = $C000
unstrobe        = $C010
click           = $C030
graphics        = $C050
text            = $C051
fullscreen      = $C052
primary         = $C054
secondary       = $C055
hires           = $C057
pbutton0        = $C061

PREAD           = $FB1E

; TODO:
;   - game over graphic
;   - sound + disable toggle UI
;   - custom graphics for text
;   ? clamp keyboard aiming on edge of screen
;   ? draw warning line at bottom of screen
;   ? block counts > 255
;   ? difficulty setting

            org $6000

start
            ; init random number seed values

            lda #$12
            sta seed0
            lda #$34
            sta seed1

            ldx #1
            stx input_mode          ; paddle mode by default

;           ldx #1
            stx difficulty

;           ldx #1
            stx high_index
            stx high_bcd0
            dex
            stx high_bcd1

            jsr clear1
            jsr erase_screen_grid

            ; draw "wave:"
            ldx #wave_x
            ldy #wave_y
            jsr set_text_xy
            ldx #<wave_str
            ldy #>wave_str
            jsr draw_string

            ; draw "high:"
            ldx #high_x
            ldy #high_y
            jsr set_text_xy
            ldx #<high_str
            ldy #>high_str
            jsr draw_string

            sta primary
            sta fullscreen
            sta hires
            sta graphics

restart     jsr clear_grid
            jsr erase_screen_grid

            ldx #1
            stx wave_bcd0
            stx wave_index
            stx appl_count
            dex
            stx wave_bcd1
            stx wave_mag

            lda #default_start_x
            sta start_x
            jmp first_wave_mode

wave_str    dc.b 5,"WAVE:"
high_str    dc.b 5,"HIGH:"

; TODO: move this code down lower in file

clear_grid  subroutine

            lda #grid_height
            sta grid_row
            ldy #0
.loop1      lda #block_type_edge
            sta block_grid,y
            sta block_grid+grid_width-1,y
            lda #0
            sta block_counts,y
            iny
            ldx #grid_width-2
.loop2      sta block_grid,y
            sta block_counts,y
            iny
            dex
            bne .loop2
            sta block_counts,y
            iny
            dec grid_row
            bne .loop1
            rts
;
; scroll down grid block and block count tables
;
scroll_blocks subroutine

            ldy #grid_size-grid_width-1
.loop1      lda block_grid,y
            sta block_grid+grid_width,y
            lda block_counts,y
            sta block_counts+grid_width,y
            dey
            bpl .loop1

            ldy #grid_width-2
            lda #0
.loop2      sta block_grid,y
            sta block_counts,y
            dey
            bne .loop2
            rts
;
; find the highest empty line and use that +1 to compute the line
;   that balls complete at
;
compute_max_ball_y subroutine

            ldy #grid_size-2
.1          ldx #grid_width-2
.2          lda block_grid,y
            bne .3
            dey
            dex
            bne .2
            dey
            dey
            bpl .1
            ldy #0
.3          lda grid_screen_rows+grid_width,y
            clc
            adc #block_height
            cmp #192-ball_height-text_height
            bcc .4
            lda #192-ball_height-text_height
.4          sta max_ball_y
            rts

;=======================================
; Wave mode
;=======================================

next_wave_mode subroutine
            ldx wave_index
            cpx #255            ; cap wave at 255
            bcs .1

            inx
            sed
            lda wave_bcd0
;           clc
            adc #1
            sta wave_bcd0
            lda wave_bcd1
            adc #0
            sta wave_bcd1
            cld

            ; check for highest wave

            cpx high_index
            bcc .1
            stx high_index
            lda wave_bcd0
            sta high_bcd0
            lda wave_bcd1
            sta high_bcd1
.1          stx wave_index

            ; compute wave magnitude, used to scale block fill levels

            txa
            ldx #0
            sec
            sbc #1
            lsr
            lsr
            lsr
            beq .3
.2          inx
            lsr
            bne .2
.3          stx wave_mag

first_wave_mode subroutine

            ; draw wave number

            ldx #wave_x+5
            ldy #wave_y
            jsr set_text_xy
            ldx wave_bcd1
            lda wave_bcd0
            jsr draw_digits3

            ; draw highest wave number
            ldx #high_x+5
            ldy #high_y
            jsr set_text_xy
            ldx high_bcd1
            lda high_bcd0
            jsr draw_digits3

            ; randomly place new ball block

            jsr random
            tax
            ldy mod7,x
            iny
            lda #block_type_appl
            sta block_grid,y
            jsr eor_block_appl

            ; get number of blocks to create, from 2 to 7

.1          jsr random
            tax
            ldy mod7,x
            beq .1
            iny
            sty block_index

            ; create new blocks on top row, allowing at most one block double-up

.2          jsr random
            tax
            ldy mod7,x
            iny
            lda block_grid,y
            cmp #block_type_appl    ; exclude block that already holds a new appl
            beq .2
            lda block_counts,y
            beq .3
            cmp wave_index
            bne .2
.3          clc
            adc wave_index
            bcc .4
            lda #255                ; clamp counter to maximum value
.4          sta block_counts,y
            lda #block_type_square
            sta block_grid,y
            dec block_index
            bne .2

            ; draw new blocks on top row and existing blocks with new wave_mag

            ldy #1
.5          lda block_counts,y
            beq .6
            lda block_grid,y
            bpl .6
            sty block_index
            jsr draw_block
            ldy block_index
.6          iny
            cpy #grid_size-grid_width-1
            bne .5

            ; erase any appl blocks before they scroll to bottom

            ldy #grid_size-grid_width*2+1
.7          lda block_grid,y
            cmp #block_type_appl
            bne .8
            sty block_index
            lda #0
            sta block_grid,y
            jsr eor_block_appl
            ldy block_index
.8          iny
            cpy #grid_size-grid_width-1
            bne .7

            jsr scroll_blocks
            jsr scroll_screen_grid
            jsr compute_max_ball_y

            ; check for game over when blocks in next-to bottom row are non-zero

            ldy #1
.9          lda block_grid+grid_size-grid_width*2,y
            bmi game_over
            iny
            cpy #grid_width-1
            bne .9
            beq aiming_mode     ; always

game_over   subroutine

            ; TODO: put up "game over" graphic

            ldx input_mode
            beq .2

            ; wait for a button press to end game and start a new one
            ; (make sure button has been seen as up, then wait for it to
            ;   go down again before restarting)
.1          bit pbutton0
            bmi .1

.2          lda keyboard
            bpl .3
            and #$5f            ; force upper case and remove high bit
            bit unstrobe
            ldx #0
            cmp #"K"
            beq .new_mode
            inx
            cmp #"J"
            beq .new_mode
            ; ignore arrows so they don't trigger new game
            cmp #$08            ; left arrow
            beq .2
            cmp #$15            ; right arrow
            beq .2
            ldx input_mode
            beq .to_restart

.new_mode   stx input_mode
.3          lda input_mode
            beq .2

.joy_mode   bit pbutton0
            bpl .2

.to_restart
            ; TODO: erase "game over" graphic
            ; TODO: erase old text?
            jmp restart

;=======================================
; Aiming mode
;=======================================

aiming_mode subroutine

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
            lda #default_start_y
            sta y_int
            jsr eor_appl        ; draw aiming ball

            lda #$80
            sta angle
            lda #0
            sta button_up
            bit unstrobe

.loop1      jsr update_angle
            lda angle_dx_frac
            sta dx_frac
            lda angle_dx_int
            sta dx_int
            lda angle_dy_frac
            sta dy_frac
            lda angle_dy_int
            sta dy_int

            jsr draw_dots

.loop2      lda keyboard
            bpl .1
            bit unstrobe
            and #$5f            ; force upper case and remove high bit
            beq .0              ; <space> forced to upper case
            ldx #0
            cmp #"K"
            beq .new_mode
            inx
            cmp #"J"
            beq .new_mode
            ldx input_mode
            bne .joy_mode
            cmp #$08            ; left arrow
            beq .key_left
            cmp #$15            ; right arrow
            beq .key_right
            cmp #$0d            ; return
            bne .1
.0          jmp running_mode

.new_mode   stx input_mode
            txa
            bne .joy_mode
            ldy #$80
            bne .common         ; always
.1          ldx input_mode
            beq .loop2
.joy_mode   ldx #1
            bit pbutton0        ; check for paddle 0 button press
            bpl .2
            ldx button_up       ; must have seen button up once in case
            bne running_mode    ;   unthrottled mode was being used coming in
.2          stx button_up

            ldx #0
            jsr PREAD           ; read paddle 0 value
            cpy #min_angle      ; clamp value to [2,253]
            bcs .3
            ldy #min_angle
.3          cpy #max_angle
            bcc .4
            ldy #max_angle
.4          cpy angle
            beq .loop2          ; loop until something changes
            bne .common         ; always

.key_left   ldy angle
            dey
            cpy #min_angle
            bcs .common
            iny
            bcc .common         ; always

.key_right  ldy angle
            iny
            cpy #max_angle+1
            bcc .common
            dey

.common     sty angle
            jsr erase_dots
            jsr random          ; update random number on input change
            jmp .loop1

;=======================================
; Running mode
;=======================================

running_mode subroutine

            ldx x_int
            lda y_int
            jsr eor_appl        ; erase aiming ball
            jsr erase_dots

            lda #send_delay
            sta send_countdown

            lda #0
            sta applz_visible
            sta appl_slots
            sta button_up
            beq .first          ; always

            ; update and redraw visible applz

.loop1      ldx #0
.loop2      stx appl_index
            jsr update_appl
            ldx appl_index
            inx
            cpx appl_slots
            bne .loop2

            lda keyboard
            bpl .1
            bit unstrobe
            and #$7f
            ldx #0
            cmp #"K"
            beq .new_mode
            inx
            cmp #"J"
            beq .new_mode
            ldx input_mode
            bne .joy_mode
            lda button_up
            eor #1
            sta button_up
.new_mode   stx input_mode
.1          ldx input_mode
            beq .key_mode

            ; check for throttling ball movement speed
            ;   (must have seen button up once in case
            ;   unthrottled mode was being used coming in)

.joy_mode   ldx button_up
            bne .2
            bit pbutton0
            bmi .throttle
            ldx #1
            stx button_up
.2          bit pbutton0
            bmi .nodelay
            bpl .throttle       ; always

.key_mode   lda button_up
            bne .nodelay

            ; add delay for low ball counts
            ;   (~600 cycles per ball below throttle_ballz)

.throttle   lda #throttle_ballz
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
            lda #default_start_y
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
;
; set and convert applz_ready to BCD
;
; on entry:
;   a: applz_ready value
;
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

draw_applz_ready subroutine
            ldx start_x
            lda div7,x
            clc
            adc #grid_screen_left-1
            cmp #grid_screen_left+3
            bcs .1
            lda #grid_screen_left+3
.1          cmp #grid_screen_left+(grid_width-2)*3
            bcc .2
            lda #grid_screen_left+(grid_width-2)*3
.2          tax
            ldy #192-text_height
            jsr set_text_xy
            lda applz_ready
            beq .3
            ldx applz_ready_bcd1
            lda applz_ready_bcd0
            jmp draw_digits3
.3          ldx #<space3_str
            ldy #>space3_str
            jmp draw_string

space3_str  dc.b 3,"   "

;
; draw new aiming dots until edge of screen is hit
;   (or richochet if difficulty == 0)
;
draw_dots   subroutine

            lda #0
            sta dot_count

            ldx #1
.loop1      stx appl_index

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

            lda #4              ; 4 delta steps between dots
            sta dot_repeat

.loop2      lda x_frac,x
            clc
            adc dx_frac,x
            sta x_frac,x
            lda x_int,x
            adc dx_int,x
            sta x_int,x

            ; check for dot reaching left or right edge of grid

            cmp #21
            bcc .3
            cmp #grid_screen_width-21-ball_width
            bcc .4
.3          lda difficulty
            bne .exit
            jsr reflect_x
.4
            lda y_frac,x
            clc
            adc dy_frac,x
            sta y_frac,x
            lda y_int,x
            adc dy_int,x
            sta y_int,x

            ; check for hitting top of grid

            cmp #grid_screen_top
            bcc .exit

            dec dot_repeat
            bne .loop2

            jsr eor_dot

            ldx appl_index
            inx
            stx dot_count
            cpx #max_aim_dots
            bne .loop1
.exit       rts
;
; erase all previously drawn aiming dots
;
erase_dots  subroutine

            ldx #1
            bne .2          ; always
.1          stx appl_index
            jsr eor_dot
            ldx appl_index
            inx
.2          cpx dot_count
            bcc .1
            rts
;
; remove ball off bottom of screen
;
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

            ; use final x for start/aim x clamped to reasonable values

            lda x_int,x
            cmp #block_width
            bcs .1
            lda #block_width
.1          cmp #grid_screen_width-21-ball_width-1
            bcc .2
            lda #grid_screen_width-21-ball_width-1
.2          tax

            ; force ball position to byte alignment + 1
            sec
            sbc mod7,x
;           sec
            adc #0                  ; +1 to align ball with text
            sta start_x
            rts
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

            lda x_frac,x                        ; 4
            clc                                 ; 2
            adc dx_frac,x                       ; 4
            sta x_frac,x                        ; 4
            lda x_int,x                         ; 4
            sta ball_x                          ; 3
            adc dx_int,x                        ; 4
            sta x_int,x                         ; 4
            sta ball_dx                         ; 3
            tay                                 ; 2

            lda grid_x_table+block_gap,y        ; 4
            sta grid_left                       ; 3
            sec                                 ; 2
            sbc grid_x_table+ball_width-1,y     ; 4
            sta grid_dx                         ; 3

            lda y_frac,x                        ; 4
            clc                                 ; 2
            adc dy_frac,x                       ; 4
            sta y_frac,x                        ; 4
            lda y_int,x                         ; 4
            sta ball_y                          ; 3
            adc dy_int,x                        ; 4
            sta y_int,x                         ; 4

            cmp #grid_screen_top-2              ; 2
            bcc .reverse_dy                     ; 2
            cmp max_ball_y                      ; 3
            bcs .ball_done                      ; 2

.post_reverse_d7
            sta ball_dy                         ; 3
            tay                                 ; 2

            lda grid_y_table+block_gap,y        ; 4
            sta grid_top                        ; 3
            cmp grid_y_table+ball_height-1,y    ; 4
            bne up_down                         ; 2 ; crossed horizontal block edge
            clc                                 ; 2
            adc grid_left                       ; 3
            tay                                 ; 2
            lda grid_dx                         ; 3
            bne left_right_y1                   ; 2 ; crossed vertical block edge

            lda block_grid,y                    ; 4
            bne collide_appl                    ; 2/3

            jmp move_appl                       ; 4
                                                ; = 128
; reflect ball at top of screen

.reverse_dy jsr reflect_y
            lda y_int,x
            jmp .post_reverse_d7

.ball_done  cmp ball_y
            bcc .post_reverse_d7                ; ball must be moving down to be done
            beq .post_reverse_d7
            jmp ball_done
;
; check for collision with appl block
;
collide_appl
            ldx appl_count
            inx
            beq .1              ; clamp to 255
            stx appl_count
.1          lda #0
            sta block_grid,y
            jsr eor_block_appl
            ldx appl_index      ; restore ball index
            jmp move_appl
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
            bmi .bounce_dy
            jmp move_appl

.down       lda block_grid+grid_width,y
            bmi .next_y_bounce_dy
            jmp move_appl

.next_y_bounce_dy
            tya
            clc
            adc #grid_width
            tay
.bounce_dy  jsr reflect_y
            jmp hit_move_appl
;
; ball moving horizontally crossed vertical edge on single block
;
;   +-+   +-+
;  OO |   | OO
;   +-+   +-+
;
left_right_y1
            lda dx_int,x        ; moving left or right?
            bmi .left
            iny                 ; look at right edge
.left       lda block_grid,y
            bmi .bounce_dx
            jmp move_appl

.bounce_dx  jsr reflect_x
            jmp hit_move_appl
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
            bmi .dfg
            lda block_grid,y
            bmi .ae
            lda block_grid+1,y
            bmi .b
            jmp move_appl_ur

.ae         lda block_grid+1,y
            bmi .e

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
            bmi .g
            lda block_grid+1,y
            bmi .f

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
            bmi .cfg
            lda block_grid+1,y
            bmi .be
            lda block_grid,y
            bmi .a
            jmp move_appl_ul

.be         lda block_grid,y
            bmi .e

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
            bmi .g
.cf         lda block_grid,y
            bmi .f

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
            bmi .bfg
            lda block_grid+grid_width,y
            bmi .ce
            lda block_grid+grid_width+1,y
            bmi .d
            jmp move_appl_dr

.ce         lda block_grid+grid_width+1,y
            bmi .e

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
            bmi .g
.bf         lda block_grid+grid_width+1,y
            bmi .f

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
            bmi .afg
            lda block_grid+grid_width+1,y
            bmi .de
            lda block_grid+grid_width,y
            bmi .c
            jmp move_appl_dl

.de         lda block_grid+grid_width,y
            bmi .e

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
            bmi .g
.af         lda block_grid+grid_width,y
            bmi .f

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
            rts
;
; handle hitting a grid block
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
            jsr compute_max_ball_y
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

; divide by 20 * grid_width table to convert y position into grid row offset
; (page aligned so table look-ups don't cost extra cycle for crossing page boundary)
            align 256
grid_y_table
            ds  block_height+grid_screen_top,0*grid_width
            ds  block_height,1*grid_width
            ds  block_height,2*grid_width
            ds  block_height,3*grid_width
            ds  block_height,4*grid_width
            ds  block_height,5*grid_width
            ds  block_height,6*grid_width
            ds  block_height,7*grid_width
            ds  block_height,8*grid_width
            ds  block_height,9*grid_width
;
; scroll all visible grid blocks down by one on screen
;
scroll_screen_grid subroutine

            lda #block_height/scroll_delta
            sta grid_row
.loop1      ldx #191
.loop2      lda hires_table_lo-scroll_delta,x
            clc
            adc #grid_screen_left+3
            sta .mod1+1
            lda hires_table_hi-scroll_delta,x
            sta .mod1+2

            lda hires_table_lo,x
;           clc
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
            cpx #grid_screen_top+scroll_delta-1
            bne .loop2

.loop3      lda hires_table_lo,x
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
            cpx #grid_screen_top-1
            bne .loop3

            dec grid_row
            bne .loop1
            rts
;
; erase the entire screen grid area and draw side bars
;
erase_screen_grid subroutine

            ldx #0
.1          lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh

            ldy #grid_screen_left+2
            cpx #grid_border_height
            bcs .2

            ; draw filled bar on top/left of grid

            lda #$f8
            sta (screenl),y
            iny

            lda #$7f
            bne .3              ; always

            ; draw bar on left of grid

.2          lda #$18
            sta (screenl),y
            iny

            ; clear main grid

            lda #0
.3          sta (screenl),y
            iny
            cpy #grid_width*3-3+grid_screen_left
            bne .3

            ; draw bar on right of grid

            lda #$03
            sta (screenl),y

            inx
            cpx #192
            bne .1
            rts
;
; update aiming angle delta values
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

            ; double all values

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
            rts

.left       eor #$7f
            tay

            ; double all values

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
            rts
;
; table of 128 sine values from [0, PI / 2)
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
; draw a single grid block
;
; on entry
;   y: grid index of block
;   a: block type
;
wave_masks  dc.b 0, 1, 3, 7, 15, 31
wave_shifts dc.b 0, 2, 1, 0, -1, -2

draw_block  subroutine

            ldx #$00
            lda block_counts,y
            cmp #64
            bcc .1
            beq .1
            ldx #$80
.1          stx block_color

            ; compute number of top empty and bottom full lines in block

            lda block_counts,y
            sec
            sbc #1
            pha
            ldx wave_mag
            beq .3
.2          lsr
            dex
            bne .2
.3          sta block_bot
            lda #block_height_nogap-2   ; minus top and bottom line
            sec
            sbc block_bot
            bcs .4
            lda #block_height_nogap-2   ; minus top and bottom line
            sta block_bot
            lda #0
.4          sta block_top

            ; compute number of dots in partial line based on wave magnitude

            pla
            ldx wave_mag
            and wave_masks,x
            sta block_mid
            lda wave_shifts,x
            tax
            bpl .6
.5          lsr block_mid
            inx
            bmi .5
.6          lda block_mid
.7          dex
            bmi .8
            asl
            bcc .7             ; always
.8          asl
            asl
            sta block_mid
            beq .9
            dec block_top
.9

draw_lines  ldx grid_screen_rows,y
            lda grid_screen_cols,y
            tay

            ; first full line
            lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            inx
            lda #$55
            ora block_color
            sta (screenl),y
            iny
            lda #$2a
            ora block_color
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60
            ora #$15
            ora block_color
            sta (screenl),y
            dey
            dey

            ; top empty lines
            lda block_top
            beq .11
.10         lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            inx
            lda #$01
            ora block_color
            sta (screenl),y
            iny
            lda block_color
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60
            ora #$10
            ora block_color
            sta (screenl),y
            dey
            dey
            dec block_top
            bne .10
.11
            ; partial line
            lda block_mid
            beq .12
            lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            inx
            txa
            pha
            ldx block_mid
            lda block_lines+0,x
            ora block_color
            sta (screenl),y
            iny
            lda block_lines+1,x
            ora block_color
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60
            ora block_lines+2,x
            ora block_color
            sta (screenl),y
            dey
            dey
            pla
            tax
.12
            ; bottom full lines
.13         lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            inx
            lda #$55
            ora block_color
            sta (screenl),y
            iny
            lda #$2a
            ora block_color
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60
            ora #$15
            ora block_color
            sta (screenl),y
            dey
            dey
            dec block_bot
            bpl .13             ; draw bottom line by letting count go negative
            rts

block_lines hex 01001000        ; 0 (empty)
            hex 05001000        ; 1
            hex 15001000        ; 2
            hex 55001000        ; 3
            hex 55021000        ; 4
            hex 550a1000        ; 5
            hex 552a1000        ; 6
            hex 552a1100        ; 7
            hex 552a1500        ; 8 (full)
;
; erase a single grid block
;
; on entry
;   y: grid index of block
;
erase_block subroutine

            lda grid_screen_rows,y
            tax
            clc
            adc #block_height_nogap
            sta block_bot
            lda grid_screen_cols,y
            tay
.loop       lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh
            lda #0
            sta (screenl),y
            iny
            sta (screenl),y
            iny
            lda (screenl),y
            and #$60            ; clip out block gap
            sta (screenl),y
            dey
            dey
            inx
            cpx block_bot
            bne .loop
            rts
;
; draw an in-grid appl shape
;
; on entry
;   y: grid index of block
;
eor_block_appl subroutine

block_appl_height = 9

            lda grid_screen_rows,y
            clc
            adc #(block_height_nogap-block_appl_height)/2
            sta block_top
;           clc
            adc #block_appl_height
            sta block_bot

            lda grid_screen_cols,y
            sta block_left
;           clc
            adc #block_width/7
            sta block_mid

            ; choose shifted or non-shifted shape based on column

            ldx #0
            lda block_left
            lsr
            bcs .noshift
            ldx #block_appl_height*(block_width/7)
.noshift
            ldy block_top
.loop1      lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy block_left
.loop2      lda block_appl_shapes,x
            eor (screenl),y
            sta (screenl),y
            inx
            iny
            cpy block_mid
            bne .loop2
            ldy block_top
            iny
            sty block_top
            cpy block_bot
            bne .loop1
            rts

block_appl_shapes
            dc.b %00000000, %00101000, %00000000
            dc.b %00000000, %00001000, %00000000
            dc.b %00000000, %00101010, %00000000
            dc.b %11000000, %10101010, %10000001
            dc.b %11000000, %10101010, %10000000
            dc.b %00000000, %01010101, %00000000
            dc.b %11000000, %10101010, %10000000
            dc.b %11000000, %10101010, %10000001
            dc.b %10000000, %11010101, %10000000

            dc.b %00000000, %00010100, %00000000
            dc.b %00000000, %00000100, %00000000
            dc.b %00000000, %00010101, %00000000
            dc.b %10100000, %11010101, %10000000
            dc.b %10100000, %10010101, %10000000
            dc.b %01000000, %00101010, %00000000
            dc.b %10100000, %10010101, %10000000
            dc.b %10100000, %11010101, %10000000
            dc.b %11000000, %10101010, %10000000

            assume grid_height=10
            assume block_height=20

grid_screen_rows
            ds  grid_width,grid_screen_top+0
            ds  grid_width,grid_screen_top+20
            ds  grid_width,grid_screen_top+40
            ds  grid_width,grid_screen_top+60
            ds  grid_width,grid_screen_top+80
            ds  grid_width,grid_screen_top+100
            ds  grid_width,grid_screen_top+120
            ds  grid_width,grid_screen_top+140
            ds  grid_width,grid_screen_top+160
            ds  grid_width,grid_screen_top+180

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
; eor a single aiming dot shape
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
            ldx dots_lo,y
.loop       ldy ypos
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
            beq .skip0
            eor (screenl),y
            sta (screenl),y
.skip0      inx
            inc ypos
            dec ycount
            bne .loop
            rts

;-------------------------------------------------------------------------------
;-------------------------------------------------------------------------------

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
;           clc
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
;           clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_dx             ; 3     x/dx
            lda div7,y              ; 4
;           clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
;           clc
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
;           clc
            adc ball_y              ; 3
            sec                     ; 2
            sbc ball_dy             ; 3
            beq .exit               ; 2/3
            asl                     ; 2
;           clc
            adc #1                  ; 3

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_dy             ; 3     y/dy
;           clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_x              ; 3     x/dx
            lda div7,y              ; 4
;           clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
;           clc
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
;           clc
            adc ball_dy             ; 3
            sec                     ; 2
            sbc ball_y              ; 3
            beq .exit               ; 2/3   no movement
            asl                     ; 2
;           clc
            adc #1                  ; 3     + ur_dl

            tay                     ; 2
            asl                     ; 2     * 8 pre-shifted shapes
            asl                     ; 2
            asl                     ; 2
            tax                     ; 2

            lda ball_y              ; 3     y/dy
;           clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_dx             ; 3     x/dx
            lda div7,y              ; 4
;           clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
;           clc
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
;           clc
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
;           clc
            adc appl_heights,y      ; 4
            sta ycount              ; 3

            ldy ball_x              ; 3     x/dx
            lda div7,y              ; 4
;           clc
            adc #grid_screen_left   ; 2
            sta ball_x              ; 3

            txa                     ; 2
;           clc
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
; eor a ball shape without movement
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
;           clc
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
;
; clear primary screen to black
;
clear1      subroutine

            ldx #0
            txa
.loop       sta $2000,x
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
            bne .loop
            rts

dots_lo     dc.b #<dot0
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
