; Applz -- Copyright (C) 2022-23 Sean Callahan

            processor 6502

        mac ASSUME
            if ({1})
            else
                echo "Assumption failed: ", {1}
                err
            endif
        endm

; NOTE: SET_PAGE and CHECK_PAGE are used to confirm that a branch
;   in a performance critical loop isn't costing an extra cycle

    mac SET_PAGE
PAGE set *
    endm

    mac CHECK_PAGE
        if ((*-1)/256) != (PAGE/256)
            echo "### page crossing detected:",*,"-^",PAGE
            err
        endif
    endm

            include trace.s

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

grid_screen_left    = 14    ; in bytes
grid_screen_top     = 4     ; implicit dependencies
grid_width          = 9     ; includes left and right padding
grid_height         = 10    ; includes bottom dead space
grid_size           = grid_width*grid_height
grid_screen_width   = grid_width*3*7
grid_border_height  = 2

wave_x              = 3     ; in bytes
wave_y              = 192-24
high_x              = wave_x
high_y              = wave_y+8

throttle_applz      = 16    ; under this ball count, add delay

send_delay          = 8

scroll_delta        = 4     ; number of lines stepped per grid scroll

default_start_x     = 92
default_start_y     = 192-ball_height-8

text_height         = 6     ; excluding line gaps

; zero page variables

temp            = $00
xpos            = $01
ypos            = $02
ycount          = $03

top_digit       = $04
skip_delay      = $05   ; briefly used during title screen

input_mode      = $10   ; 0: keyboard, 1: paddle
difficulty      = $11
applz_visible   = $12   ; applz visible on screen (<= appl_slots)
appl_slots      = $13   ; slots used in tables, both visible and complete

appl_index      = $14

dot_count       = $15
dot_repeat      = $16
dot_phase       = $17
prev_dot_count  = $18

angle           = $19
angle_dx_frac   = $1a
angle_dx_int    = $1b
angle_dy_frac   = $1c
angle_dy_int    = $1d

pbutton0_prev   = $20   ; paddle 0 button value from previous check

start_x         = $21   ; variable position relative to grid edge
send_countdown  = $22

appl_count      = $23   ; total number of applz the player has collected

screenl         = $24
screenh         = $25
seed0           = $26
seed1           = $27

ball_x          = $28
ball_dx         = $29
ball_y          = $2a
ball_dy         = $2b
max_ball_y      = $2c

grid_left       = $30
grid_dx         = $31
grid_top        = $32
grid_row        = $33

block_index     = $34
block_color     = $35
block_top       = $36
block_left      = $37
block_mid       = $38
block_bot       = $39

block_hit0      = $3a
block_hit1      = $3b
block_appl_hit  = $3c

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

fast_applz      = $4a   ; send applz without throttling

sound_enabled   = $50
sound_throttle  = $51
sound_line      = $52
sound_delay     = $53
sound_duration  = $54
sound_count     = $55

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

; X tweak W and M characters
; - put fast screen clear back in with comments
;   (not clear gaps, Bruce Artwick of Sublogic)
; *** cap ball count at 255 but allow wave up to 999
; *** (wave_index might still cap at 255)

            org $6000

start
            ; init random number seed values
            lda #$12
            sta seed0
            lda #$34
            sta seed1

            ldx #0
            stx pbutton0_prev
            inx
            stx input_mode          ; paddle mode by default

;           ldx #1                  ; normal difficulty
            stx difficulty

;           ldx #1
            stx sound_enabled
            stx high_index
            stx high_bcd0
            dex
            stx high_bcd1

            jsr init_sound
            jsr title_screen

restart     jsr open_screen_grid
            jsr clear_grid

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

;=======================================
; Wave mode
;=======================================

next_wave_mode subroutine
            jsr play_wave_done

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

            jsr draw_wave_high

            ; draw wave number

            ldx #wave_x+7
            ldy #wave_y
            jsr set_text_xy
            ldx wave_bcd1
            lda wave_bcd0
            jsr draw_digits3

            ; draw best wave number

            ldx #high_x+7
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
            jsr set_block_bit
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
            jsr set_block_bit
            dec block_index
            bne .2

            ; draw new blocks on top row and existing blocks with new wave_mag

            ldy #1
.5          lda block_counts,y
            beq .6
            lda block_grid,y
            bpl .6
            sty block_index
            jsr draw_game_block
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
            jsr clear_block_bit
            jsr eor_block_appl
            ldy block_index
.8          iny
            cpy #grid_size-grid_width-1
            bne .7

            jsr scroll_grid
            jsr scroll_screen_grid
            jsr compute_max_ball_y

            ; game over when blocks in next-to bottom row are non-zero

            lda block_bits+grid_height-2
            beq aiming_mode
            ; fall through

game_over   subroutine

            jsr draw_game_over
            jsr play_game_over

            lda #128
            jsr reset_logo

.1          jsr animate_logo
            lda keyboard
            bpl .4
            and #$5f            ; force upper case and remove high bit
            bit unstrobe
            cmp #"S"
            bne .2
            jsr toggle_sound
            jmp .1

.2          ldx #0
            cmp #"K"
            beq .new_mode
            inx
            cmp #"J"
            beq .new_mode
            ; ignore arrows so they don't trigger new game
            cmp #$08            ; left arrow
            beq .1
            cmp #$15            ; right arrow
            beq .1
            ldx input_mode
            beq .to_restart

.new_mode   stx input_mode
.4          lda input_mode
            beq .1

.joy_mode   lda pbutton0
            tax
            eor pbutton0_prev
            bpl .1
            stx pbutton0_prev
            txa
            bpl .1

.to_restart jsr abort_logo
.5          jsr animate_logo
            bcs .5
            jsr close_screen_grid
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
            bit unstrobe

            lda #0
            sta dot_count
            lda #2
            sta dot_phase

.loop1      jsr update_angle
            lda angle_dx_frac
            sta dx_frac
            lda angle_dx_int
            sta dx_int
            lda angle_dy_frac
            sta dy_frac
            lda angle_dy_int
            sta dy_int

.loop2      jsr update_dots
            jsr animate_logo

            lda keyboard
            bpl .5
            bit unstrobe
            and #$5f            ; force upper case and remove high bit
            bne .1              ; <space> forced to upper case
            jmp .running

.1          cmp #"S"
            bne .2
            jsr toggle_sound
            jmp .5

.2          cmp #"D"
            bne .4
.new_diff   ldx wave_index      ; only allowed on first wave
            dex
            bne .loop1
            jsr erase_dots
            ldx difficulty
            inx
            cpx #3
            bne .3
            ldx #0
.3          stx difficulty
            lda #0
            sta dot_count
            jmp .loop2

.4          ldx #0
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
            bne .5
            beq .running        ; always

.new_mode   stx input_mode
            txa
            bne .joy_mode
            lda #$80
            bne .common         ; always

.5          ldx input_mode
            beq .loop2

.joy_mode   lda pbutton0        ; check for paddle 0 button press
            tax
            eor pbutton0_prev
            bpl .6
            stx pbutton0_prev
            txa
            bmi .running        ; if newly down, start running
.6          ldx #0
            jsr PREAD           ; read paddle 0 value
            tya
            ldx difficulty
            cmp min_angles,x    ; clamp value
            bcs .7
            lda min_angles,x
.7          cmp max_angles,x
            bcc .8
            lda max_angles,x
.8          cmp angle
            bne .common
            jmp .loop2          ; loop until something changes

.key_left   lda #1
            ldx difficulty
            ldy pbutton0
            bpl .9
            lda #8
.9          sta temp
            lda angle
            sec
            sbc temp
            bcc .10
            cmp min_angles,x
            bcs .common
.10         lda min_angles,x
            bpl .common         ; always

.key_right  lda #1
            ldx difficulty
            ldy pbutton0
            bpl .11
            lda #8
.11         clc
            adc angle
            bcs .12
            cmp max_angles,x
            bcc .common
.12         lda max_angles,x

.common     sta angle
            jsr random          ; update random number on input change
            jmp .loop1

.running    jsr abort_logo
.13         jsr animate_logo
            bcs .13
            ; fall through

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
            sta fast_applz
            RESET_TRACE
            START_TRACE
            BEGIN_EVENT Wave
            BEGIN_EVENT GameLoop
            jmp .first

            ; update and redraw visible applz

.loop1      END_EVENT GameLoop
            BEGIN_EVENT GameLoop
            lda #throttle_applz
            sta sound_throttle
            ldx #0
.loop2      stx appl_index

            lda #-1
            sta block_hit0
            sta block_hit1
            sta block_appl_hit

            BEGIN_EVENT Update
            jsr update_appl
            jsr update_sound
            END_EVENT Update

            ldy block_hit0
            bmi .no_block
            jsr update_block
            ldy block_hit1
            bmi .no_block
            jsr update_block
.no_block   ldy block_appl_hit
            bmi .no_apple
            jsr eor_block_appl
            jsr play_appl_capture
.no_apple
            ldx appl_index
            inx
            cpx appl_slots
            bne .loop2

            lda keyboard
            bpl .2
            bit unstrobe
            and #$5f            ; force upper case and remove high bit
            cmp #"S"
            bne .1
            jsr toggle_sound
            jmp .2

.1          ldx #0
            cmp #"K"
            beq .new_mode
            inx
            cmp #"J"
            beq .new_mode
            ldx input_mode
            bne .joy_mode
            lda fast_applz
            eor #1
            sta fast_applz
.new_mode   stx input_mode
.2          ldx input_mode
            beq .throttle

            ; check for throttling ball movement speed
            ;   (must have seen button up once in case
            ;   unthrottled mode was being used coming in)

.joy_mode   lda pbutton0
            tax
            eor pbutton0_prev
            bpl .throttle
            stx pbutton0_prev
            ldy #0
            txa
            bpl .3
            iny
.3          sty fast_applz

            ; add delay for low ball counts
            ;   (~600 cycles per ball below throttle_applz)
.throttle   lda fast_applz
            bne .nodelay
            lda sound_throttle
            beq .nodelay
            BEGIN_EVENT Throttle
.delay1     ldy #120             ; 120 * 5 cycles
.delay2     dey
            bne .delay2
            jsr update_sound
            lda sound_throttle
            bne .delay1
            END_EVENT Throttle
.nodelay
            lda applz_ready     ; any applz left to send?
            bne .try_send
            lda applz_visible   ; any still visible?
            beq .wave_done
            jmp .loop1
.wave_done  END_EVENT GameLoop
            END_EVENT Wave
            STOP_TRACE
            jmp next_wave_mode  ; no, start next wave

.try_send   dec send_countdown  ; check if it has been long enough to send
            beq .do_send
            jmp .loop1

.do_send    lda #send_delay     ; reset send delay countdown
            sta send_countdown

.first      BEGIN_EVENT Send
            ldx appl_slots
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
            BEGIN_EVENT ApplzReady
            jsr update_applz_ready
            END_EVENT ApplzReady

            inc applz_visible

            ldy appl_index
            ldx x_int,y
            lda y_int,y
            jsr eor_appl
            jsr play_ball_send

            jsr update_sound
            END_EVENT Send
            jmp .loop1

;=======================================
; End of game loop
;=======================================

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
            clc
            bcc .0              ; always
update_applz_ready
            sec
.0          php
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
            plp
            lda applz_ready
            beq .4
            ldx applz_ready_bcd1
            lda applz_ready_bcd0
            bcc .3
            jmp update_digits3
.3          jmp draw_digits3
.4          jmp erase_digits3

;-----------------------------------------------------------
;
; remove ball off bottom of screen
;
ball_done   subroutine

            ldx ball_x
            lda ball_y
            jsr eor_appl
            jsr play_ball_done

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

;=======================================
; Apple movement update logic
;=======================================

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
            txa
            pha
            lda #0              ; always at top
            jsr play_wall_hit
            pla
            tax
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
            sty block_appl_hit
            jsr clear_block_bit
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
;
; on exit:
;   x: ball index
;   y: unchanged
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
;   y: block index
;
; on exit:
;   y: block index
;
hit_block   subroutine
            lda block_counts,y
            beq .3              ; border blocks have zero count
            sec
            sbc #1
            sta block_counts,y
            bne .1
            lda #0
            sta block_grid,y

            jsr clear_block_bit
.1          lda block_hit0
            bpl .2
            sty block_hit0
            rts
.2          sty block_hit1
            rts
.3          sty block_index
            lda yind_table,y
            jsr play_wall_hit
            ldy block_index
            rts
;
; erase or redraw a block that was hit during the update_appl call
;
; on entry:
;   y: block index
;
update_block subroutine
            lda block_counts,y
            bne .1
            jsr erase_block
            jsr compute_max_ball_y
            jsr play_block_destroyed
            jmp update_sound

.1          lda yind_table,y
            pha
            lda block_grid,y
            jsr draw_game_block
            pla
            jsr play_block_hit
            jmp update_sound
;
; divide by 21 table to convert x position into grid column
;
            align 256
grid_x_table
            SET_PAGE
            ds  block_width,0
            ds  block_width,1
            ds  block_width,2
            ds  block_width,3
            ds  block_width,4
            ds  block_width,5
            ds  block_width,6
            ds  block_width,7
            ds  block_width,8
            CHECK_PAGE
;
; divide by 20 * grid_width table to convert y position into grid row offset
;
            align 256
grid_y_table
            SET_PAGE
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
            CHECK_PAGE

;=======================================
; Aiming dots logic
;=======================================

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
; update/animate new aiming dots until edge of screen is hit
;   (or richochet if difficulty == 0)
;
update_dots subroutine

            ldy dot_phase
            iny
            tya
            and #3
            sta dot_phase
            tay
            iny
            sty dot_repeat
            lda dot_count
            sta prev_dot_count

            ldx #1
.loop1      cpx dot_count
            bcs .1
            stx appl_index
            jsr eor_dot
            ldx appl_index
.1
            ; copy position and delta from previous dot

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
            bne .5
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
            bcc .5

            dec dot_repeat
            bpl .loop2

            lda #3
            sta dot_repeat

            stx appl_index
            jsr eor_dot
            ldx appl_index

            inx
            txa
            ldy difficulty
            cmp max_aim_dots,y
            bcs .5
            stx appl_index
            jmp .loop1

.5          stx dot_count
.6          inx
            cpx prev_dot_count
            bcs .7
            stx appl_index
            jsr eor_dot
            ldx appl_index
            bne .6              ; always

; throttle to maximum number of dots

.7          lda max_aim_dots+0  ; always use highest value here
            sec
            sbc dot_count
            tax
            beq .10
.8          ldy #880/5          ; burn about 880 cycles per dot
.9          dey
            bne .9
            dex
            bne .8
.10         rts

min_angles  dc.b 6,6,16
max_angles  dc.b 255-6,255-6,255-16
max_aim_dots dc.b 32,32,10

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
            ldx dots_offs,y
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

dots_offs   dc.b 0,6,12
            dc.b 18,24,30
            dc.b 36

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

;=======================================
; Fast apple redrawing code
;=======================================

; eor move:
;
;   67 * 7 + 93 = 474 + 93 = 567
;   67 * 6 + 93 = 407 + 93 = 500
;   67 * 5 + 93 = 340 + 93 = 433
;
; simple erase/draw:
;
;   373 * 2 = 746

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

hit_move_appl_ul subroutine

            jsr hit_block

move_appl_ul subroutine
            BEGIN_EVENT MoveUL

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

            ; TODO: update_sound call?

            SET_PAGE
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
            CHECK_PAGE
                                    ; = 67 (340/407/474)
.exit       END_EVENT MoveUL
            rts

hit_move_appl_ur subroutine

            jsr hit_block

move_appl_ur subroutine
            BEGIN_EVENT MoveUR

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

            ; TODO: update_sound call?

            SET_PAGE
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
            CHECK_PAGE
                                    ; = 67 (340/407/474)
.exit       END_EVENT MoveUR
            rts

move_down   lda ball_dx             ; 3
            cmp ball_x              ; 3
            bcs move_appl_dr        ; 2/3
            bcc move_appl_dl        ; 3 always

hit_move_appl_dl subroutine

            jsr hit_block

move_appl_dl subroutine
            BEGIN_EVENT MoveDL

            lda ball_x              ; 3     ((dx * 4) + dy) * 2 + ur_dl
            sec                     ; 2
            sbc ball_dx             ; 3
            asl                     ; 2
            asl                     ; 2
;           clc
            adc ball_dy             ; 3
            sec                     ; 2
            sbc ball_y              ; 3
            beq .exit               ; 2/3   no movement (remove for sound eveness?)
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

            ; TODO: update_sound call?

            SET_PAGE
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
            CHECK_PAGE
                                    ; = 67 (340/407/474)
.exit       END_EVENT MoveDL
            rts

hit_move_appl_dr subroutine

            jsr hit_block

move_appl_dr subroutine
            BEGIN_EVENT MoveDR

            lda ball_dx             ; 3     ((dx * 4) + dy) * 2
            sec                     ; 2
            sbc ball_x              ; 3
            asl                     ; 2
            asl                     ; 2
;           clc
            adc ball_dy             ; 3
            sec                     ; 2
            sbc ball_y              ; 3
            beq .exit               ; 2/3   no movement (remove for sound eveness?)
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

            ; TODO: update_sound call?

            SET_PAGE
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
            CHECK_PAGE
                                    ; = 67 (340/407/474)
.exit       END_EVENT MoveDR
            rts

;-------------------------------------------------------------------------------
;
; eor a ball shape without movement
;
; on entry:
;   X: x coordinate
;   A: y coordinate
;
eor_appl    subroutine
            BEGIN_EVENT EorBall

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

            SET_PAGE
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
            CHECK_PAGE

.exit       END_EVENT EorBall
            rts

;=======================================
; End of fast apple redrawing code
;=======================================

            include title.s
            include grid.s
            include sound.s
            include data.s
