;=======================================
; Grid data and screen block routines
;=======================================

;
; clear/reset all grid data
;
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

            ldy #grid_height-1
            lda #0
.loop3      sta block_bits,y
            dey
            bpl .loop3
            rts
;
; scroll down grid block and block count tables
;
scroll_grid   subroutine

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

            ldy #grid_height-1
.loop3      lda block_bits-1,y
            sta block_bits,y
            dey
            bne .loop3
            lda #0
            sta block_bits+0
            rts
;
; find the highest empty line and use that +1 to compute the line
;   that balls complete at
;
; NOTE: This uses block_bits in order to optimize the process of finding
;   the lowest empty row.  Walking through block_grid took long enough
;   (about 675 cycles) to throw off update_sound timing, so this
;   optimization was needed.
;
compute_max_ball_y subroutine
            BEGIN_EVENT ComputeMaxY

            ; ignore partial bottom row and "game over" row
            ldy #grid_height-3
.1          lda block_bits,y
            bne .2
            dey
            bpl .1
            iny
.2          lda max_ball_y_table,y
            sta max_ball_y

            END_EVENT ComputeMaxY
            rts

max_ball_y_table
            dc.b grid_screen_top+block_height*2
            dc.b grid_screen_top+block_height*3
            dc.b grid_screen_top+block_height*4
            dc.b grid_screen_top+block_height*5
            dc.b grid_screen_top+block_height*6
            dc.b grid_screen_top+block_height*7
            dc.b grid_screen_top+block_height*8
            dc.b 192-ball_height-text_height
;
; On entry:
;   Y: block grid index
;
; On exit:
;   Y: block grid index
;
set_block_bit subroutine
            ldx yind_table,y
            lda xbit_table,y
            ora block_bits,x
            sta block_bits,x
            rts

clear_block_bit subroutine
            ldx yind_table,y
            lda xbit_table,y
            eor #$ff
            and block_bits,x
            sta block_bits,x
            rts
;
; block index to grid y index
;
yind_table  ds grid_width,0
            ds grid_width,1
            ds grid_width,2
            ds grid_width,3
            ds grid_width,4
            ds grid_width,5
            ds grid_width,6
            ds grid_width,7
            ds grid_width,8
            ds grid_width,9
            ASSUME grid_height=10

xbit_table  dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
            dc.b 0,1,2,4,8,16,32,64,0
;           dc.b 0,1,2,4,8,16,32,64,0
            ASSUME grid_width=9
            ASSUME grid_height=10

block_bits  ds  grid_height,0

;
; scroll all visible grid blocks down by one on screen
;
scroll_screen_grid subroutine

            lda #block_height/scroll_delta
            sta grid_row
.loop1      ldx #191
            SET_PAGE
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
            CHECK_PAGE

.loop3      lda hires_table_lo,x
            clc
            adc #grid_screen_left+3
            sta .mod3+1
            lda hires_table_hi,x
            sta .mod3+2
            ldy #(grid_width-2)*3-1
            lda #0
            SET_PAGE
.mod3       sta $ffff,y
            dey
            bpl .mod3
            CHECK_PAGE
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
.loop1      lda hires_table_lo,x
            sta screenl
            lda hires_table_hi,x
            sta screenh

            ldy #grid_screen_left+2
            cpx #grid_border_height
            bcs .2

            ; draw filled bar on top/left of grid

            lda #$78
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
            bne .loop1
            rts
;
; draw a specific block color/fill level for
;   title and game start block animation
;
; on entry
;   y: grid index of block
;   block color: $00 or $80
;
draw_title_block subroutine
            lda #block_height_nogap-2-2
            sta block_top
            lda #4*4
            sta block_mid
            lda #2-1
            sta block_bot
            bpl draw_block      ; always
;
; compute block fill level and color, then draw
;
; on entry
;   y: grid index of block
;   a: block type
;
wave_masks  dc.b 0, 1, 3, 7, 15, 31
wave_shifts dc.b 0, 2, 1, 0, -1, -2

draw_game_block  subroutine

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
.9          ; fall through
;
; on entry
;   y: grid index of block
;   block_top, block_mid, block_bot, block_color set up
;
; xpos is unchanged
;
draw_block  subroutine
            BEGIN_EVENT DrawBlock

            ldx grid_screen_rows,y
            txa
            clc
            adc #block_height_nogap/2
            sta sound_line
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
            beq .2

            SET_PAGE
.1          cpx #192
            beq .21
            cpx sound_line
            bne .11
            jsr update_sound
.11         lda hires_table_lo,x
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
            bne .1
            CHECK_PAGE
.2
            ; partial line
            lda block_mid
            beq .3
            cpx #192
.21         beq .41
            cpx sound_line
            bne .22
            jsr update_sound
.22         lda hires_table_lo,x
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
.3
            ; bottom full lines
            SET_PAGE
.4          cpx #192
.41         beq .5
            cpx sound_line
            bne .42
            jsr update_sound
.42         lda hires_table_lo,x
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
            bpl .4              ; draw bottom line by letting count go negative
            CHECK_PAGE
.5
            END_EVENT DrawBlock
            rts
;
; erase a single grid block, split into two parts so update_sound
;   can be called often enough
;
; on entry
;   y: grid index of block
;
erase_block subroutine
            BEGIN_EVENT EraseBlock

            ; assume clamping to 192 is only needed on block_mid, not block_bot
            ; (+/-1 to better distribute time for update_sound)
            ASSUME (block_height_nogap & 1) == 0
            ASSUME grid_screen_top + (grid_height-1) * block_height + block_height_nogap/2+1 >= 192

            lda grid_screen_rows,y
            tax
            clc
            adc #block_height_nogap/2+1
            cmp #192
            bcc .1
            lda #192
            sta block_mid
            lda #0
            sta block_bot
            beq .2              ; always

.1          sta block_mid
;           clc
            adc #block_height_nogap/2-1
.2          sta block_bot
            lda grid_screen_cols,y
            tay

            SET_PAGE
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
            cpx block_mid
            bne .loop
            CHECK_PAGE

            lda block_bot
            beq .done
            sta block_mid
            jsr update_sound    ; saves/restores X and Y
            lda #0
            sta block_bot
            beq .loop           ; always

.done       END_EVENT EraseBlock
            rts
;
; draw an in-grid appl shape
;
; NOTE: An extra blank line has been added to the end of the shape to
;   pad drawing time, evening out the time between update_sound calls.
;
; on entry
;   y: grid index of block
;
eor_block_appl subroutine
            BEGIN_EVENT EorApple

block_appl_height = 10

            lda grid_screen_rows,y
            clc
            adc #(block_height_nogap-block_appl_height)/2
            sta block_top
;           clc
            adc #block_appl_height/2
            sta sound_line
;           clc
            adc #block_appl_height/2
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

            SET_PAGE
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
            cpy sound_line
            bne .1
            jsr update_sound
.1          cpy block_bot
            bne .loop1
            CHECK_PAGE

            jsr update_sound
            END_EVENT EorApple
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
            dc.b %10000000, %10000000, %10000000

            dc.b %00000000, %00010100, %00000000
            dc.b %00000000, %00000100, %00000000
            dc.b %00000000, %00010101, %00000000
            dc.b %10100000, %11010101, %10000000
            dc.b %10100000, %10010101, %10000000
            dc.b %01000000, %00101010, %00000000
            dc.b %10100000, %10010101, %10000000
            dc.b %10100000, %11010101, %10000000
            dc.b %11000000, %10101010, %10000000
            dc.b %10000000, %10000000, %10000000

            ASSUME grid_height=10
            ASSUME block_height=20

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

            ASSUME grid_screen_left=14
            ASSUME block_width=21

grid_screen_cols
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
            dc.b 14,17,20,23,26,29,32,35,38
