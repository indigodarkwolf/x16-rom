.include "mac.inc"
.include "regs.inc"
.include "banks.inc"
.include "graphics.inc"
.include "fb.inc"

.import jsrfar

.macro graph_call addr
    jsr jsrfar
    .word addr
    .byte BANK_GRAPH
.endmacro

.export GRAPH_clear
.export GRAPH_draw_image
.export GRAPH_draw_line
.export GRAPH_draw_oval
.export GRAPH_draw_rect
.export GRAPH_init
.export GRAPH_move_rect
.export GRAPH_set_colors
.export GRAPH_set_window

ram_bank = 0

.segment "GRAPH"

GRAPH_clear:
    KVARS_START
    graph_call gr_GRAPH_clear
    KVARS_END
    rts

GRAPH_draw_image:
    graph_call gr_GRAPH_draw_image
    rts

GRAPH_draw_line:
    graph_call gr_GRAPH_draw_line
    rts

GRAPH_draw_oval:
    graph_call gr_GRAPH_draw_oval
    rts

GRAPH_draw_rect:
    graph_call gr_GRAPH_draw_rect
    rts

GRAPH_init:
    KVARS_START
    graph_call gr_GRAPH_init
    KVARS_END
    rts

GRAPH_move_rect:
    graph_call gr_GRAPH_move_rect
    rts

GRAPH_set_colors:
    graph_call gr_GRAPH_set_colors
    rts

GRAPH_set_window:
    KVARS_START
    graph_call gr_GRAPH_set_window
    KVARS_END
    rts
