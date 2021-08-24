
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

        do double_speed
send_delay  = 8
        else
send_delay  = 16
        fin

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

start_x       = $1b     ; variable position relative to grid edge
send_countdown = $1c

appl_count  = $1f       ; total number of applz the player has collected

screenl     = $20
screenh     = $21
sourcel     = $22
sourceh     = $23
seed0       = $24
seed1       = $25

grid_left   = $30
grid_right  = $31
grid_top    = $32
grid_bottom = $33

grid_col    = $34
grid_row    = $35
block_index = $36
block_type  = $37
block_color = $38
block_top   = $39
block_left  = $3a
block_mid   = $3b
block_bot   = $3c

wave_index  = $40
wave_bcd0   = $41
wave_bcd1   = $42

applz_ready = $43       ; applz ready but not yet launched
applz_ready_bcd0 = $44
applz_ready_bcd1 = $45

state       = $1000     ; high bit set when visible/active
x_frac      = $1100
x_int       = $1200
oldx_frac   = $1300
oldx_int    = $1400
dx_frac     = $1500
dx_int      = $1600
y_frac      = $1700
y_int       = $1800
oldy_frac   = $1900
oldy_int    = $1a00
dy_frac     = $1b00
dy_int      = $1c00

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
;   - keyboard aiming support?
;   - remove aiming richochet
;
; PERF:
;   - eor delta ball drawing
;   - zpage old ball position instead of table
;   - double dx/dy values
;   - throttle ball redraw rate

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

wave_str    STR "WAVE:"

; TODO: move this code down lower in file

clear_grid  lda #grid_height
            sta grid_row
            lda #0
            tay
:1          iny
            ldx #grid_width-2
:2          sta block_grid,y
            sta block_counts,y
            iny
            dex
            bne :2
            iny
            dec grid_row
            bne :1
            rts

scroll_blocks
            ldy #grid_size-grid_width-1
:1          lda block_grid,y
            sta block_grid+grid_width,y
            lda block_counts,y
            sta block_counts+grid_width,y
            dey
            bpl :1

            ldy #grid_width-2
            lda #0
:2          sta block_grid,y
            sta block_counts,y
            dey
            bne :2
            rts

; TODO: page align
block_grid  db -1, 0, 0, 0, 0, 0, 0, 0,-1
            ; TODO: set -1 as part of clear
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1

block_counts
            ds grid_size,0

;=======================================
; Wave mode
;=======================================

; TODO: check for game over
;*** first time through, random number will always be the same

next_wave_mode
            ldx wave_index
            cpx #255            ; cap wave at 255
            bcs :1
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
:1          stx wave_index
            stx appl_count      ; TODO: for now, bump applz along with wave

first_wave_mode

            ; draw wave number

            ldx #wave_x+5
            ldy #wave_y
            jsr set_text_xy
            lda wave_bcd1
            jsr draw_number
            lda wave_bcd0
            jsr draw_number

            ; get number of blocks to create, from 2 to 6

:1          jsr random
            tax
            lda mod7,x
            cmp #2
            bcc :1
            sta block_index

            ; create new blocks on top row, allowing at most one block double-up

:2          jsr random
            tax
            ldy mod7,x
            lda block_counts+1,Y
            beq :3
            cmp wave_index
            bcs :2
:3          clc
            adc wave_index
            sta block_counts+1,y
            lda #block_type1        ; TODO: pick block_type2
            sta block_grid+1,y
            dec block_index
            bne :2

            ; draw new blocks on top row

            ldy #1
:4          sty block_index
            lda block_grid,y
            beq :5
            jsr draw_block
            ldy block_index
:5          iny
            cpy #grid_width-1
            bne :4

            jsr scroll_blocks
            jsr scroll_screen_grid

            ; fall through

;=======================================
; Aiming mode
;=======================================

aiming_mode lda #16         ;*** dot count
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

:1          jsr update_angle
            lda angle_dx_frac
            sta dx_frac
            lda angle_dx_int
            sta dx_int
            lda angle_dy_frac
            sta dy_frac
            lda angle_dy_int
            sta dy_int

            jsr draw_dotz

:2          bit pbutton0        ; check for paddle 0 button press
            bmi running_mode
            ldx #0
            jsr PREAD           ; read paddle 0 value
            cpy #2              ; clamp value to [2,253]
            bcs :3              ; TODO: clamp a little more?
            ldy #2
:3          cpy #253
            bcc :4
            ldy #253
:4          cpy angle
            beq :2              ; loop until something changes
            sty angle

            jsr erase_dotz

            ;*** keep disabled while debugging
            ;jsr random          ; update random number on input change
            jmp :1

;=======================================
; Running mode
;=======================================

running_mode
            ldx x_int
            lda y_int
            jsr eor_appl        ; erase aiming ball
            jsr erase_dotz

            lda #1
            sta send_countdown
            lda #0
            sta applz_visible
            sta appl_slots
            beq :first          ; always

            ; update and redraw visible applz

:loop1      ldx #0
:loop2      stx appl_index

            lda state,x         ; already complete?
            bpl :skip4

            jsr update_appl

            lda state,x         ; newly complete?
            bpl :skip4

        do double_speed
        else
            lda x_int,x         ; check for change in x position
            cmp oldx_int,x
            bne :skip3

            lda y_int,x         ; check for change in y position
            cmp oldy_int,x
            beq :skip4
        fin

:skip3      jsr erase_appl
            jsr draw_appl
:skip4
            ldx appl_index
            inx
            cpx appl_slots
            bne :loop2

            ; check for more applz to send

            lda applz_ready     ; check for applz left to send
            bne :5
            lda applz_visible
            bne :loop1

            jmp next_wave_mode

:5          dec send_countdown  ; check if it has been long enough to send
            bne :loop1

            lda applz_visible   ; no more than 255 applz simultaneously
            cmp #255
            beq :loop1

:first      ldx appl_slots      ; get slot for new appl
            cpx #255
            beq :8
;           cpx applz_visible
;           bne :8
            inc appl_slots      ; consume next empty slot
            bne :9              ; always

:8          lda state-1,x       ; search for open existing slot
            bpl :9
            dex
            bne :8
            ;*** should have found a slot ***
:hang       beq :hang       ;***

:9          lda #$80            ; mark as active
            sta state,x

            lda start_x         ; set start position
            sta x_int,x
            sta oldx_int,x
            lda #start_y
            sta y_int,x
            sta oldy_int,x
            lda #0
            sta x_frac,x
            sta y_frac,x
            sta oldx_frac,x
            sta oldy_frac,x

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

            jsr draw_appl       ;*** not needed on first pass ***

            lda #send_delay     ; reset send delay countdown
            sta send_countdown
            jmp :loop1

; set and convert applz_ready to BCD
;
; on entry:
;   a: applz_ready value

set_applz_ready
            sta applz_ready
            tax
            ldy #0
:0          txa
            sec
            sbc #100
            bcc :1
            tax
            iny
            bne :0              ; always
:1          sty applz_ready_bcd1

            ldy #0
:2          txa
            sec
            sbc #10
            bcc :3
            tax
            iny
            bne :2              ; always

:3          stx applz_ready_bcd0
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

draw_dotz   ldx #1
:1          stx appl_index

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

        do double_speed
            lda #4
        else
            lda #8
        fin
            sta grid_col            ;***
            ldx appl_index
:2          jsr update_dot
            dec grid_col
            bne :2

            jsr eor_dot

            ldx appl_index
            inx
            cpx dot_count
            bne :1
            rts


erase_dotz  ldx #1
:1          stx appl_index
            jsr eor_dot
            ldx appl_index
            inx
            cpx dot_count
            bne :1
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
update_dot  lda x_frac,x
            sta oldx_frac,x
            clc
            adc dx_frac,x
            sta x_frac,x
            lda x_int,x
            sta oldx_int,x
            adc dx_int,x
            sta x_int,x

            ;*** get rid of ricochet
            cmp #21
            bcc :1
            cmp #grid_screen_width - 21 - ball_width
            bcc :2
:1          jsr reflect_x
:2
            lda y_frac,x
            sta oldy_frac,x
            clc
            adc dy_frac,x
            sta y_frac,x
            lda y_int,x
            sta oldy_int,x
            adc dy_int,x
            sta y_int,x
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
update_appl lda x_frac,x                                ; 4
            sta oldx_frac,x                             ; 4
            clc                                         ; 2
            adc dx_frac,x                               ; 4
            sta x_frac,x                                ; 4
            lda x_int,x                                 ; 4
            sta oldx_int,x                              ; 4
            adc dx_int,x                                ; 4
            sta x_int,x                                 ; 4
            tay                                         ; 2
            lda grid_x_table + 1,y                      ; 4
            sta grid_left                               ; 3
            lda grid_x_table + 1 + ball_width - 1,y     ; 4
            sec                                         ; 2
            sbc grid_left                               ; 3
            sta grid_right                              ; 3

            lda y_frac,x                                ; 4
            sta oldy_frac,x                             ; 4
            clc                                         ; 2
            adc dy_frac,x                               ; 4
            sta y_frac,x                                ; 4
            lda y_int,x                                 ; 4
            sta oldy_int,x                              ; 4
            adc dy_int,x                                ; 4
            sta y_int,x                                 ; 4

            cmp #192-ball_height                        ; 2     ; check for ball y wrapping
            bcs :reverse_dy                             ; 2

:post_reverse_d7
            tay                                         ; 2
            lda grid_y_table + block_gap,y              ; 4
            sta grid_top                                ; 3
            lda grid_y_table + ball_height - 1,y        ; 4
            sec                                         ; 2
            sbc grid_top                                ; 3
            sta grid_bottom                             ; 3

            lda grid_right                              ; 3
            bne left_right                              ; 2     ; crossed vertical block edge
            lda grid_bottom                             ; 3
            bne up_down_x1                              ; 2     ; crossed horizontal block edge
            rts                                         ; 6     ; TODO: loop here instead of jsr/rts
                                                        ; = 130

; reflect ball at top of screen

:reverse_dy cmp #192+ball_height+1
            bcc :ball_done
            jsr reflect_y
            jmp :post_reverse_d7

; remove ball off bottom of screen

:ball_done  jsr erase_appl
            ldx appl_index
            lda #0
            sta state,x
            dec applz_visible
            bne :1
            lda applz_ready
            bne :1
            lda x_int,x         ; use final x for start/aim x
            sta start_x
:1          rts

left_right  lda grid_bottom
            bne left_right_y2   ; crossing two blocks vertically
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
            bmi :left
            iny                 ; look at right edge
:left       lda block_grid,y
            bne bounce_dx
            rts
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
;
; ball moving vertically crossed horizontal edge on single block
;
;   +-+   O
;   | |  +O+
;   +O+  | |
;    O   +-+
;
up_down_x1  lda grid_left
            clc
            adc grid_top
            tay
            lda dy_int,x
            bpl :down

:up         lda block_grid,y
            bne bounce_dy
            rts

:down       lda block_grid+grid_width,y
            bne next_y_bounce_dy
            rts

diag_up     lda dx_int,x
            bmi :diag_up_left
;
;   a      b      c      d      e      f      g
; +-+      +-+                +-+-+    +-+  +-+..
; | |      | |                | | |    | |  | | .
; +-O      O-+           O-+  +-O-+    O-+  +-O-+
;  O      O             O| |   O      O| |   O| |
;                        +-+           +-+    +-+
;
:diag_up_right
            lda block_grid+grid_width+1,y
            bne :dfg
            lda block_grid,y
            bne bounce_dy           ; case a,e
            iny
            lda block_grid,y
            beq :nob
            jsr reflect_y           ; case b
            jmp bounce_dx
:nob        rts
:dfg        lda block_grid,y
            beq :df                 ; case d,f
            jsr reflect_y           ; case g
:df         iny
            bne next_y_bounce_dx    ; always
;
;   a      b       c     d      e      f      g
; +-+      +-+                +-+-+  +-+    ..+-+
; | |      | |                | | |  | |    . | |
; +-O      O-+   +-O          +-O-+  +-O    +-O-+
;    O      O    | |O            O   | |O   | |O
;                +-+                 +-+    +-+
;
:diag_up_left
            lda block_grid+grid_width,y
            bne :cfg
            iny
            lda block_grid,y
            bne bounce_dy           ; case b,e
            dey
            lda block_grid,y
            beq :noa
            jsr reflect_y           ; case a
            jmp bounce_dx
:noa        rts
:cfg        lda block_grid+1,y
            beq next_y_bounce_dx    ; case c,f
            jsr reflect_y           ; case g
        ;   bne next_y_bounce_dx

next_y_bounce_dx
            tya
            clc
            adc #grid_width
            tay
bounce_dx   jsr reflect_x
            jmp hit_block

next_y_bounce_dy
            tya
            clc
            adc #grid_width
            tay
bounce_dy   jsr reflect_y
            jmp hit_block

diag_down   lda dx_int,x
            bmi :diag_down_left
;
;   a      b       c     d      e      f      g
;          +-+                         +-+    +-+
;         O| |    O     O      O      O| |   O| |
;          O-+   +-O     O-+  +-O-+    O-+  +-O-+
;                | |     | |  | | |    | |  | | .
;                +-+     +-+  +-+-+    +-+  +-+..
;
:diag_down_right
            lda block_grid+1,y
            bne :bfg
            lda block_grid+grid_width,y
            bne next_y_bounce_dy    ; case c,e
            iny
            lda block_grid+grid_width,y
            beq :nod
            jsr reflect_y           ; case d
            jmp next_y_bounce_dx
:nod        rts
:bfg        lda block_grid+grid_width,y
            beq :bf                 ; case b,f
            jsr reflect_y           ; case g
:bf         iny
            bne bounce_dx           ; always
;
;   a      b       c     d      e      f      g
; +-+                                +-+    +-+
; | |O              O     O      O   | |O   | |O
; +-O            +-O     O-+  +-O-+  +-O    +-O-+
;                | |     | |  | | |  | |    . | |
;                +-+     +-+  +-+-+  +-+    ..+-+
;
:diag_down_left
            lda block_grid,y
            bne :afg
            iny
            lda block_grid+grid_width,y
            bne next_y_bounce_dy    ; case d,e
            dey
            lda block_grid+grid_width,y
            beq :noc
            jsr reflect_y           ; case c
            jmp next_y_bounce_dx
:noc        rts
:afg        lda block_grid+grid_width+1,y
            beq bounce_dx           ; case a,f
            jsr reflect_y           ; case g
            jmp bounce_dx

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
reflect_x   lda oldx_frac,x     ; back up to old x
            sta x_frac,x
            lda oldx_int,x
            sta x_int,x
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

reflect_y   lda oldy_frac,x     ; back up to old y
            sta y_frac,x
            lda oldy_int,x
            sta y_int,x
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
; handle hitting block
;
; on entry:
;   x: ball index
;   y: block index
;
; on exit:
;   x: ball index
;
hit_block   lda block_counts,y
            beq :1              ; border blocks have zero count
            sec
            sbc #1
            sta block_counts,y
            bne :2

            lda #0
            sta block_grid,y
            jsr erase_block
            ldx appl_index      ; restore ball index
:1          rts

:2          lda block_grid,y
            jsr draw_block
            ldx appl_index      ; restore ball index
            rts

; divide by 21 table to convert x position into grid column
; (page aligned so table look-ups don't cost extra cycle for crossing page boundary)
            ds  \,0
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
            ds  \,0
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
scroll_screen_grid
            lda #block_height/scroll_delta
            sta grid_row
:1          ldx #191
:2          lda hires_table_lo,x
            clc
            adc #grid_screen_left+3
            sta screenl
            lda hires_table_hi,x
            sta screenh

            lda hires_table_lo-scroll_delta,x
        ;   clc
            adc #grid_screen_left+3
            sta sourcel
            lda hires_table_hi-scroll_delta,x
            sta sourceh

            ldy #grid_width-2*3-1
            ;*** self-modify these instead ***
:3          lda (sourcel),y
            sta (screenl),y
            dey
            bpl :3

            dex
            cpx #scroll_delta-1
            bne :2

:4          lda hires_table_lo,x
            clc
            adc #grid_screen_left+3
            sta screenl
            lda hires_table_hi,x
            sta screenh
            ldy #grid_width-2*3-1
            lda #0
            ;*** self-modify this instead ***
:5          sta (screenl),y
            dey
            bpl :5
            dex
            bpl :4

            dec grid_row
            bne :1
            rts

erase_screen_grid
            ldx #0
:1          lda hires_table_lo,x
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
:2          sta (screenl),y
            iny
            cpy #grid_width*3-3+grid_screen_left
            bne :2

            ; draw bar on right of grid

            lda #$03
            sta (screenl),y

            inx
            cpx #192
            bne :1
            rts

;---------------------------------------
;
; entry
;   a: angle 0 (full left) to 255 (full right)
;
; NOTE: shortcut (ones-complement) negation being used
;
update_angle
            lda angle
            tax
            bpl :left

:right      and #$7f
            tax
            eor #$7f
            tay

        do double_speed
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
        fin
            rts

:left       eor #$7f
            tay

        do double_speed
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
        fin
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
draw_block
            ; choose color based on block type
;           ldx #$d5
;           cmp #block_type2
;           bne :1
            ldx #$55
:1          stx block_color

            lda grid_screen_rows,y
            tax
            clc
            adc #block_height-block_gap-1
            sta block_bot

            lda #block_height-block_gap
            sec
            sbc block_counts,y
            beq :10
            bcs :11
:10         lda #1
:11         clc
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
            bpl :3              ; always

            ; draw empty box lines

:2          lda hires_table_lo,x
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
:3          inx
            cpx block_mid
            bne :2
            beq :5              ; always

            ; draw full box lines

:4          lda hires_table_lo,x
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
:5          cpx block_bot
            bne :4

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

            db  %01010101, %00101010, %00010101     ; filled line (8/8)
            db  %01010001, %00101010, %00010101     ;             (7/8)
            db  %01000001, %00101010, %00010101     ;             (6/8)
            db  %00000001, %00101010, %00010101     ;             (5/8)

            db  %00000001, %00101000, %00010101     ;             (4/8)
            db  %00000001, %00100000, %00010101     ;             (3/8)
            db  %00000001, %00000000, %00010101     ;             (2/8)

            db  %00000001, %00000000, %00010100     ;             (1/8)
            db  %00000001, %00000000, %00010000     ; empty line  (0/8)

;
; on entry
;   y: grid index of block
;
erase_block
            lda grid_screen_rows,y
            tax
            clc
            adc #block_height-block_gap
            sta block_bot
            lda grid_screen_cols,y
            tay
:1          lda hires_table_lo,x
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
            bne :1
            rts

            err grid_height-10
            err block_height-20
            err grid_screen_top-0

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

            err grid_screen_left-6
            err block_width-21

grid_screen_cols
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
            db  6,9,12,15,18,21,24,27,30
;
; eor the dot shape
;
eor_dot     ldy appl_index
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
            jmp eor_loop

;
; erase appl at old position using table data
;
erase_appl  ldy appl_index          ; 3
            ldx oldx_int,y          ; 4
            lda oldy_int,y          ; 4
            jmp eor_appl            ; 3

;
; draw appl at new position using table data
;
draw_appl   ldy appl_index          ; 3
            ldx x_int,y             ; 4
            lda y_int,y             ; 4
            ; fall through
;
; eor appl to specific screen coordinates
;   relative to grid edge
;
; on entry
;   x: screen x position
;   a: screen y position
;
eor_appl    sta ypos                ; 3
            lda div7,x              ; 4
            clc                     ; 2
            adc #grid_screen_left   ; 2
            sta xpos                ; 3
            lda #ball_height        ; 2
            sta ycount              ; 3
            ldy mod7,x              ; 4
            ldx applz_lo,y          ; 4
                                    ;   = 27
eor_loop    ldy ypos                ; 3
            lda hires_table_lo,y    ; 4
            sta screenl             ; 3
            lda hires_table_hi,y    ; 4
            sta screenh             ; 3
            ldy xpos                ; 3
            lda appl0,x             ; 4
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
            inx                     ; 2
            iny                     ; 2
            lda appl0,x             ; 4
            beq :1                  ; 2/3
            eor (screenl),y         ; 5
            sta (screenl),y         ; 5
:1          inx                     ; 2
            inc ypos                ; 5
            dec ycount              ; 5
            bne eor_loop            ; 3/2
                                    ;   = 69 * 5 = 340
            rts                     ; 6

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
clear1      ldx #0
            txa
:1          sta $2000,x
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
            bne :1
            rts

applz_lo    db  #<appl0
            db  #<appl1
            db  #<appl2
            db  #<appl3
            db  #<appl4
            db  #<appl5
            db  #<appl6

dotz_lo     db  #<dot0
            db  #<dot1
            db  #<dot2
            db  #<dot3
            db  #<dot4
            db  #<dot5
            db  #<dot6

            ds  \,0

appl0       db  %00001110, %00000000
            db  %00011111, %00000000
            db  %00011111, %00000000
            db  %00011111, %00000000
            db  %00001110, %00000000

appl1       db  %00011100, %00000000
            db  %00111110, %00000000
            db  %00111110, %00000000
            db  %00111110, %00000000
            db  %00011100, %00000000

appl2       db  %00111000, %00000000
            db  %01111100, %00000000
            db  %01111100, %00000000
            db  %01111100, %00000000
            db  %00111000, %00000000

appl3       db  %01110000, %00000000
            db  %01111000, %00000001
            db  %01111000, %00000001
            db  %01111000, %00000001
            db  %01110000, %00000000

appl4       db  %01100000, %00000001
            db  %01110000, %00000011
            db  %01110000, %00000011
            db  %01110000, %00000011
            db  %01100000, %00000001

appl5       db  %01000000, %00000011
            db  %01100000, %00000111
            db  %01100000, %00000111
            db  %01100000, %00000111
            db  %01000000, %00000011

appl6       db  %00000000, %00000111
            db  %01000000, %00001111
            db  %01000000, %00001111
            db  %01000000, %00001111
            db  %00000000, %00000111

; TODO cut these down in height
dot0        db  %00000000, %00000000
            db  %00001100, %00000000
            db  %00001100, %00000000
            db  %00000000, %00000000
            db  %00000000, %00000000

dot1        db  %00000000, %00000000
            db  %00011000, %00000000
            db  %00011000, %00000000
            db  %00000000, %00000000
            db  %00000000, %00000000

dot2        db  %00000000, %00000000
            db  %00110000, %00000000
            db  %00110000, %00000000
            db  %00000000, %00000000
            db  %00000000, %00000000

dot3        db  %00000000, %00000000
            db  %01100000, %00000000
            db  %01100000, %00000000
            db  %00000000, %00000000
            db  %00000000, %00000000

dot4        db  %00000000, %00000000
            db  %01000000, %00000001
            db  %01000000, %00000001
            db  %00000000, %00000000
            db  %00000000, %00000000

dot5        db  %00000000, %00000000
            db  %00000000, %00000011
            db  %00000000, %00000011
            db  %00000000, %00000000
            db  %00000000, %00000000

dot6        db  %00000000, %00000000
            db  %00000000, %00000110
            db  %00000000, %00000110
            db  %00000000, %00000000
            db  %00000000, %00000000

            ds  \,0

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

            ds  \,0

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

            ds  \,0

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

            ds  \,0

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

            put text.s

