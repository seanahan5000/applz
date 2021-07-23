
            dummy 0

;*** ENABLED/VISIBLE? ***
x_frac      db  0
oldx_frac   db  0
dx_frac     db  0

x_int       db  0
oldx_int    db  0
dx_int      db  0

y_frac      db  0
oldy_frac   db  0
dy_frac     db  0

y_int       db  0
oldy_int    db  0
dy_int      db  0

entry_size
            dend

xpos        =   $00
ypos        =   $01
ycount      =   $02

appl        =   $10
applh       =   $11
appl_end    =   $12
applh_end   =   $13
appl_index  =   $14
appl_count  =   $15

screenl     =   $20
screenh     =   $21

applz_base  =   $1000
block_table =   $0800

blocks_wide =   7
blocks_high =   7

; TODO: use correct abbreviations
keyboard    =   $C000
unstrobe    =   $C010
click       =   $C030
graphics    =   $C050
text        =   $C051
fullscreen  =   $C052
primary     =   $C054
secondary   =   $C055
hires       =   $C057

            org $6000

start
            ; clear and display screen

            jsr clear1
            sta primary
            sta fullscreen
            sta hires
            sta graphics

            ; copy default table

            ldx #blocks_high*blocks_wide-1
:loop0      lda block_defaults,x
            sta block_table,x
            dex
            bpl :loop0

            jsr draw_blocks

            lda #0
            sta appl_count
            lda #<applz_base
            sta appl
            sta appl_end
            lda #>applz_base
            sta applh
            sta applh_end

            ; create one appl

            lda appl_end
            sta appl
            lda applh_end
            sta applh
            jsr init_appl
            jsr draw_appl

            inc appl_count
            lda appl_end
            clc
            adc #entry_size
            sta appl_end
            bcc :skip1
            inc applh_end
:skip1

            ; update applz

update_loop lda #<applz_base
            sta appl
            lda #>applz_base
            sta applh

            lda appl_count
            sta appl_index

:loop2      jsr update_appl

            ; TODO: checking for movement probably not needed in real game

            ldy #x_int
            lda (appl),y
            ldy #oldx_int
            cmp (appl),y
            bne :skip3

            ldy #y_int
            lda (appl),y
            ldy #oldy_int
            cmp (appl),y
            beq :skip3

:skip3      jsr erase_appl  ;*** make sure position changed
            jsr draw_appl
:skip4

            lda appl
            clc
            adc #entry_size
            sta appl
            bcc :skip2
            inc applh
:skip2      dec appl_index
            bne :loop2

            jmp update_loop

*
* choose initial position/movement for appl
*
init_appl   ldy #x_int
            lda #70
            sta (appl),y

            ldy #x_frac
            lda #0
            sta (appl),y

            ldy #y_int
            lda #180
            sta (appl),y

            ldy #y_frac
            lda #0
            sta (appl),y

            ldy #dx_int
            lda #0
            sta (appl),y

            ldy #dx_frac
            lda #128
            sta (appl),y

            ldy #dy_int
            lda #0
            sta (appl),y

            ldy #dy_frac
            lda #20
            sta (appl),y

            ldy #oldx_int
            lda #0
            sta (appl),y

            ldy #oldy_int
            lda #0
            sta (appl),y

            rts

;
; update single appl position
;
update_appl ldy #x_frac
            lda (appl),y
            iny                 ; oldx_frac
            sta (appl),y
            clc
            iny                 ; dx_frac
            adc (appl),y
            ldy #x_frac
            sta (appl),y
            ldy #x_int
            lda (appl),y
            iny                 ; oldx_int
            sta (appl),y
            iny                 ; dx_int
            adc (appl),y
            ldy #x_int
            sta (appl),y

            cmp #145-5     ;*** ball width
            bcc :skip1          ;*** reverse context

:reverse_x
            ; back up to old x

            ldy #oldx_frac
            lda (appl),y
            dey                 ; x_frac
            sta (appl),y
            ldy #oldx_int
            lda (appl),y
            dey                 ; x_int
            sta (appl),y

            ; negate dx

            ldy #dx_frac
            lda (appl),y
            eor #$ff
            clc
            adc #1
            sta (appl),y
            ldy #dx_int
            lda (appl),y
            eor #$ff
            adc #0
            sta (appl),y
:skip1

            ldy #y_frac
            lda (appl),y
            ldy #oldy_frac
            sta (appl),y
            clc
            ldy #dy_frac
            adc (appl),y
            ldy #y_frac
            sta (appl),y
            ldy #y_int
            lda (appl),y
            ldy #oldy_int
            sta (appl),y
            ldy #dy_int
            adc (appl),y

            cmp #192-5      ;*** ball height
            bcs reverse_y   ;*** also checks against 0

            ldy #y_int
            sta (appl),y
            ;*** reflection on top, kill on bottom ***
            rts

reverse_y
            ; back up to old y

            ldy #oldy_frac
            lda (appl),y
            ldy #y_frac
            sta (appl),y

            ; negate dy

            ldy #dy_frac
            lda (appl),y
            eor #$ff
            clc
            adc #1
            sta (appl),y
            ldy #dy_int
            lda (appl),y
            eor #$ff
            adc #0
            sta (appl),y
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
; on entry:
;   x: block x
;   y: block y
;
; on exit
;   a: block value
;
get_block   txa
:loop1      dey
            bmi :skip1
            clc
            adc #blocks_wide
            bne :loop1          ; always
:skip1      tax
            lda block_table,x
            rts

;
; on entry:
;   x: block x
;   y: block y
;   a: value
;
set_block   pha
            txa
:loop1      dey
            bmi :skip1
            clc
            adc #blocks_wide
            bne :loop1          ; always
:skip1      tax
            pla
            sta block_table,x
            rts

block_type1     = 1
block_type2     = 2
block_height    = 18
block_gap       = 2

wide_blocks = 0
grid_screen_left = 9
grid_screen_top = block_height + block_gap
grid_width  = 7
grid_height = 7

grid_col    = $30
grid_row    = $31
block_index = $32
block_type  = $33
block_color = $34
block_top   = $35
block_left  = $36
block_bot   = $37

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
        do wide_blocks
            eor #$ff
        else
            eor #$80
        fin
:skip2      sta block_color

            ; block_x = (grid_col * 3) + grid_screen_left

            lda grid_col
            asl a
        do wide_blocks
            asl a
        else
            adc grid_col
        fin
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
        do wide_blocks
            sta (screenl),y
            iny
            eor #$7f
        fin
            and #$9f            ; clip out block gap
            sta (screenl),y
            dey
            dey
        do wide_blocks
            dey
        fin
            inx
            cpx block_bot
            bne :loop3
            rts

*
* draw/erase appl
*
erase_appl  ldy #oldy_int
            lda (appl),y
            sta ypos
            ldy #oldx_int
            jmp eor_appl

draw_appl   ldy #y_int
            lda (appl),y
            sta ypos
            ldy #x_int

eor_appl    lda (appl),y
            tax
            lda div7,x
            clc
            adc #grid_screen_left
            sta xpos
            ldy mod7,x
            lda applz_lo,y
            sta xloop_mod+1
            lda applz_hi,y
            sta xloop_mod+2
            lda #5
            sta ycount
            ldx #0
            ldy ypos
eor_loop    lda hires_table_lo,y
            clc
            adc xpos
            sta screenl
            lda hires_table_hi,y
            sta screenh
            ldy #0
xloop_mod   lda $0000,x
            beq :skip1
            eor (screenl),y
            sta (screenl),y
:skip1      inx
            iny
            cpy #2
            bne xloop_mod
            ldy ypos
            iny
            sty ypos
            dec ycount
            bne eor_loop
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

