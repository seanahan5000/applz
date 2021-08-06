
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
grid_screen_width = grid_width * 3 * 7  ;***  only used by dotz

send_delay  = 16

start_y     = 192 - ball_height

xpos        = $00
ypos        = $01
ycount      = $02

applz_ready   = $10     ; applz ready but not yet launched
applz_visible = $11     ; applz visible on screen (<= appl_slots)
appl_slots    = $12     ; slots used in tables, both visible and complete

appl_index  = $13
dot_count   = $14

angle         = $16
angle_dx_frac = $17
angle_dx_int  = $18
angle_dy_frac = $19
angle_dy_int  = $1a

start_x     = $1b   ; variable position relative to grid edge
send_countdown = $1c

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
block_bot   = $3b

screenl     = $20
screenh     = $21

state       = $1000 ; high bit set when visible/active
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
;   - difficulty levels (aiming with richochet)
;
; PERF:
;   - eor delta ball drawing
;   - zpage old ball position instead of table

            org $6000

start       jsr clear1
            sta primary
            sta fullscreen
            sta hires
            sta graphics

            jsr draw_blocks

            lda #72
            sta start_x
            jmp aiming_mode


clear_grid  lda #grid_height
            sta grid_row
            lda #0
            tay
:1          iny
            ldx #grid_width-2
:2          sta block_grid,y
            iny
            dex
            bne :2
            iny
            dec grid_row
            bne :1
            rts

; TODO: page align
block_grid  db -1, 1, 1, 0, 0, 0, 1, 1,-1
            db -1, 1, 0, 2, 0, 0, 1, 0,-1
            db -1, 2, 0, 0, 0, 0, 2, 1,-1
            db -1, 0, 2, 1, 0, 0, 2, 0,-1
            db -1, 1, 0, 0, 0, 1, 0, 1,-1
            db -1, 1, 0, 1, 2, 0, 0, 0,-1
            db -1, 0, 0, 0, 0, 2, 0, 0,-1
            db -1, 0, 0, 0, 2, 1, 0, 0,-1
            db -1, 0, 0, 0, 2, 1, 0, 0,-1
            db -1, 0, 0, 0, 0, 0, 0, 0,-1

;=======================================
; Aiming mode
;=======================================

aiming_mode lda #16         ;*** dot count
            sta dot_count
            lda #0
            sta appl_index

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
            jmp :1

;=======================================
; Running mode
;=======================================

running_mode
            ldx x_int
            lda y_int
            jsr eor_appl        ; erase aiming ball
            jsr erase_dotz

            lda #12             ;***
            sta applz_ready
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

            lda x_int,x         ; check for change in x position
            cmp oldx_int,x
            bne :skip3

            lda y_int,x         ; check for change in y position
            cmp oldy_int,x
            beq :skip4

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
            beq level_mode      ; always

:5          dec send_countdown  ; check if it has been long enough to send
            bne :loop1

            lda applz_visible   ; no more than 255 applz simultaneously
            cmp #255
            beq :loop1

:first      ldx appl_slots      ; get slot for new appl
            cpx #255
            beq :8
            inc appl_slots      ; consume next empty slot
            bne :9              ; always
            ;*** compress lists?
:8          lda state-1,x       ; search for open existing slot
            bpl :9
            dex
            bne :8
            ;*** should have found a slot ***

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

            dec applz_ready
            inc applz_visible

            stx appl_index
            jsr draw_appl       ;*** not needed on first pass ***

            lda #send_delay     ; reset send delay countdown
            sta send_countdown
            jmp :loop1

;---------------------------------------

; TODO: scroll blocks down, add new blocks, check for game over

level_mode
            jmp aiming_mode

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

            lda #8
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
update_appl lda x_frac,x
            sta oldx_frac,x
            clc
            adc dx_frac,x
            sta x_frac,x
            lda x_int,x
            sta oldx_int,x
            adc dx_int,x
            sta x_int,x
            tay
            lda grid_x_table + 1,y
            sta grid_left
            lda grid_x_table + 1 + ball_width - 1,y
            sec
            sbc grid_left
            sta grid_right

            lda y_frac,x
            sta oldy_frac,x
            clc
            adc dy_frac,x
            sta y_frac,x
            lda y_int,x
            sta oldy_int,x
            adc dy_int,x
            sta y_int,x

            cmp #192-ball_height    ; check for ball y wrapping
            bcs :reverse_dy

:post_reverse_d7
            tay
            lda grid_y_table + block_gap,y
            sta grid_top
            lda grid_y_table + ball_height - 1,y
            sec
            sbc grid_top
            sta grid_bottom

            lda grid_right
            bne left_right      ; crossed vertical block edge
            lda grid_bottom
            bne up_down_x1      ; crossed horizontal block edge
            rts                 ; TODO: loop here instead of jsr/rts

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
            bne bounce_dx           ; case b (TODO: zero dy?)
            rts
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
            bne bounce_dx           ; case a (TODO: zero dy?)
            rts
:cfg        lda block_grid+1,y
            beq next_y_bounce_dx    ; case c,f
            jsr reflect_y           ; case g
        ;   bne next_y_bounce_dx    ; always

next_y_bounce_dx
            tya
            clc
            adc #grid_width
            tay
bounce_dx   jsr reflect_x
            ;*** save/restore y
            ;*** decrement block count, remove block, etc ***
            ;*** watch out for border wall blocks ***
            rts

next_y_bounce_dy
            tya
            clc
            adc #grid_width
            tay
bounce_dy   jsr reflect_y
            ;*** save/restore y
            ;*** decrement block count, remove block, etc ***
            ;*** watch out for border wall blocks ***
            rts

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
            bne next_y_bounce_dx    ; case d (TODO: zero dy?)
            rts
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
            bne next_y_bounce_dx    ; case c (TODO: zero dy?)
            rts
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

; 0  21  42  63  84  105 126 147 168 189
; +---+---+---+---+---+---+---+---+---+
;   0   1   2   3   4   5   6   7   8

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

            lda sine_table,x
            sta angle_dx_frac
            lda #0
            sta angle_dx_int

            lda sine_table,y
            eor #$ff
            sta angle_dy_frac
            lda #$ff
            sta angle_dy_int
            rts

:left       eor #$7f
            tay

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

;---------------------------------------

;
; draw all blocks in grid using block_grid
;
draw_blocks ldx #0
            stx grid_col
            stx grid_row
:1          stx block_index
            lda block_grid,x
            beq :2              ; skip empty blocks
            bmi :2              ; TODO: maybe get rid of?
            ldx grid_col
            ldy grid_row
            jsr draw_block
:2          ldx grid_col
            inx
            cpx #grid_width
            bne :3
            inc grid_row
            ldx #0
:3          stx grid_col
            ldx block_index
            inx
            cpx #grid_width * grid_height
            bne :1
            rts

;
; on entry
;   x: grid column of block
;   y: grid row of block
;   a: block type
;
draw_block  stx grid_col
            sty grid_row
            sta block_type
            tax

            ; choose color based on column and block type

            lda #$d5
            cpx #block_type2
            bne :1
            eor #$80
:1          sta block_color

            ; block_x = (grid_col * 3) + grid_screen_left

            lda grid_col
            asl a
            adc grid_col
            adc #grid_screen_left
            sta block_left

            ; block_y = (grid_row * block_height) + grid_screen_top
            ; TODO: could use a table instead

            lda #grid_screen_top
            clc
            ldy grid_row
            beq :3
:2          adc #block_height
            dey
            bne :2
:3          sta block_top
            adc #block_height-block_gap
            sta block_bot

            ; fill the block

            ldx block_top
            ldy block_left
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
            eor #$7f
            and #$9f            ; clip out block gap
            sta (screenl),y
            dey
            dey
            inx
            cpx block_bot
            bne :4
            rts

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
erase_appl  ldy appl_index
            ldx oldx_int,y
            lda oldy_int,y
            jmp eor_appl

;
; draw appl at new position using table data
;
draw_appl   ldy appl_index
            ldx x_int,y
            lda y_int,y    ; fall through
;
; eor appl to specific screen coordinates
;   relative to grid edge
;
; on entry
;   x: screen x position
;   a: screen y position
;
eor_appl    sta ypos
            lda div7,x
            clc
            adc #grid_screen_left
            sta xpos
            lda #ball_height
            sta ycount
            ldy mod7,x
            ldx applz_lo,y
eor_loop    ldy ypos
            lda hires_table_lo,y
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy xpos
            lda appl0,x
            eor (screenl),y
            sta (screenl),y
            inx
            iny
            lda appl0,x
            beq :1
            eor (screenl),y
            sta (screenl),y
:1          inx
            inc ypos
            dec ycount
            bne eor_loop
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

