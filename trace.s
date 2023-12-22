
; These macros enable special opcodes supported by the RPW65
;   development environment, which can capture cycle count
;   traces that can then be used with the Chrome trace viewer.

ENABLE_TRACE = 0

    mac RESET_TRACE
        if ENABLE_TRACE
            dc.b $82,0      ; ESC0 #0
        endif
    endm

    mac START_TRACE
        if ENABLE_TRACE
            dc.b $82,1      ; ESC0 #1
        endif
    endm

    mac STOP_TRACE
        if ENABLE_TRACE
            dc.b $82,2      ; ESC0 #2
        endif
    endm

    mac BEGIN_EVENT
        if ENABLE_TRACE
            dc.b $c2,{1}    ; ESC1 #value
        endif
    endm

    mac END_EVENT
        if ENABLE_TRACE
            dc.b $e2,{1}    ; ESC2 #value
        endif
    endm

; trace event types

Wave        = 0
GameLoop    = 1
Update      = 2
Throttle    = 3
Send        = 4
MoveUL      = 5
MoveUR      = 6
MoveDL      = 7
MoveDR      = 8
ApplzReady  = 9
DrawBlock   = 10
EraseBlock  = 11
EorApple    = 12
EorBall     = 13
ComputeMaxY = 14
UpdateSound = 15
DrawChar    = 16
EraseChars  = 17
