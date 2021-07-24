
xpos        = $00
ypos        = $01
ycount      = $02

appl_index  = $14
appl_count  = $15

screenl     = $20
screenh     = $21

;*** ENABLED/VISIBLE? ***
x_frac      = $1000
x_int       = $1100
oldx_frac   = $1200
oldx_int    = $1300
dx_frac     = $1400
dx_int      = $1500
y_frac      = $1600
y_int       = $1700
oldy_frac   = $1800
oldy_int    = $1900
dy_frac     = $1a00
dy_int      = $1b00

block_table = $0800

block_type1  = 1
block_type2  = 2
block_height = 18
block_gap    = 2

grid_screen_left = 9
grid_screen_top = block_height + block_gap
grid_width  = 7
grid_height = 7
grid_size   = grid_width * grid_height

grid_col    = $30
grid_row    = $31
block_index = $32
block_type  = $33
block_color = $34
block_top   = $35
block_left  = $36
block_bot   = $37

ball_width  = 5
ball_height = 5

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

            org $6000

start
            ; clear and display screen

            jsr clear1
            sta primary
            sta fullscreen
            sta hires
            sta graphics

            ; copy default table

            ldx #grid_size-1
:loop0      lda block_defaults,x
            sta block_table,x
            dex
            bpl :loop0

            jsr draw_blocks

            lda #0
            sta appl_count

            ; create one appl

            jsr init_appl
            jsr draw_appl

            inc appl_count

            ; update applz

update_loop
            lda #0
            sta appl_index

:loop2      jsr update_appl

            ; TODO: checking for movement probably not needed in real game

            ldx appl_index

            lda x_int,x
            cmp oldx_int,x
            bne :skip3

            lda y_int,x
            cmp oldy_int,x
            beq :skip4

:skip3      jsr erase_appl  ;*** make sure position changed
            jsr draw_appl
:skip4

            lda appl_index
            cmp appl_count
            bne :loop2

            jmp update_loop

;
; choose initial position/movement for appl
;
init_appl   ldx appl_index

            lda #70
            sta x_int,x

            lda #180
            sta y_int,x

            lda #0
            sta dx_int,x

            lda #128
            sta dx_frac,x

            lda #0
            sta dy_int,x

            lda #20
            sta dy_frac,x

            lda #0
            sta oldx_int,x
            sta oldy_int,x
            sta x_frac,x
            sta y_frac,x

            rts

;
; update single appl position
;
update_appl ldx appl_index

            lda x_frac,x
            sta oldx_frac,x
            clc
            adc dx_frac,x
            sta x_frac,x
            lda x_int,x
            sta oldx_int,x
            adc dx_int,x

            cmp #145-ball_width
            bcs reverse_x

            sta x_int,x

update_y    lda y_frac,x
            sta oldy_frac,x
            clc
            adc dy_frac,x
            sta y_frac,x
            lda y_int,x
            sta oldy_int,x
            adc dy_int,x

            cmp #192-ball_height
            bcs reverse_y

            sta y_int,x
            rts

reverse_x   ; back up to old x
            lda oldx_frac,x
            sta x_frac,x
            ; negate dx
            lda dx_frac,x
            eor #$ff
            clc
            adc #1
            sta dx_frac,x
            lda dx_int,x
            eor #$ff
            adc #0
            sta dx_int,x
            jmp update_y

            ;*** reflection on top, kill on bottom ***
reverse_y   lda oldy_frac,x     ; back up to old y
            sta y_frac,x
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


; TODO: remove these
block_defaults
            db 1,1,2,2,1,1,1
            db 2,2,0,2,1,2,1
            db 1,2,1,1,1,2,0
            db 1,1,2,2,1,2,1
            db 1,2,1,2,1,1,1
            db 1,0,1,1,2,0,1
            db 1,2,1,2,1,2,2

;
; draw all blocks in grid using block_table
;
draw_blocks ldx #0
            stx grid_col
            stx grid_row
:loop1      stx block_index
            lda block_table,x
            beq :skip1
            ldx grid_col
            ldy grid_row
            jsr draw_block
:skip1      ldx grid_col
            inx
            cpx #grid_width
            bne :skip2
            inc grid_row
            ldx #0
:skip2      stx grid_col
            ldx block_index
            inx
            cpx #grid_width*grid_height
            bne :loop1
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
            bne :skip2
            eor #$80
:skip2      sta block_color

            ; block_x = (grid_col * 3) + grid_screen_left

            lda grid_col
            asl a
            adc grid_col
            adc #grid_screen_left
            sta block_left

            ; block_y = (grid_row * (block_height + block_gap)) + grid_screen_top
            ; TODO: could use a table instead

            lda #grid_screen_top
            clc
            ldy grid_row
            beq :skip1
:loop1      adc #block_height+block_gap
            dey
            bne :loop1
:skip1      sta block_top
            adc #block_height
            sta block_bot

            ; fill the block

            ldx block_top
            ldy block_left
:loop3      lda hires_table_lo,x
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
            bne :loop3
            rts

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
            ldy mod7,x
            lda applz_lo,y
            sta :loop2_mod+1
            lda applz_hi,y
            sta :loop2_mod+2
            lda #5
            sta ycount
            ldx #0
            ldy ypos
:loop1      lda hires_table_lo,y
            clc
            adc xpos
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy #0
:loop2_mod  lda $0000,x
            beq :skip1
            eor (screenl),y
            sta (screenl),y
:skip1      inx
            iny
            cpy #2
            bne :loop2_mod
            ldy ypos
            iny
            sty ypos
            dec ycount
            bne :loop1
            rts

;
; clear primary screen to black
;
clear1      ldx #0
            txa
:loop       sta $2000,x
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
            bne :loop
            rts

applz_lo    db  #<appl0
            db  #<appl1
            db  #<appl2
            db  #<appl3
            db  #<appl4
            db  #<appl5
            db  #<appl6

applz_hi    db  #>appl0
            db  #>appl1
            db  #>appl2
            db  #>appl3
            db  #>appl4
            db  #>appl5
            db  #>appl6

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

