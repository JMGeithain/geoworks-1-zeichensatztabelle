; SPDX-License-Identifier: MIT
; Copyright 2026 Johannes Moeller
; Zeichensatz Tabelle for the Ensemble 1.2 / GeoWorks 1.28 profile.
; 16 x 16 GEOS byte table, mouse/keyboard selection, clipboard copy.
%include "ensemble12.inc"
%define PROCESS_CLASS 0x40
%define FONT_DEFAULT 0x0202         ; Berkeley bitmap font
%define GRID_X 16
%define GRID_Y 52
%define CELL_W 32
%define CELL_H 20

; These locations follow the process-data layout used by the SDK application
; template. They are private application state, not GEOS API structures.
%define V_SEL     0xAC
%define V_WIN     0xAE
%define V_CODE    0xB0
%define V_ROW     0xB2
%define V_COL     0xB4
%define V_FONT    0xB6
%define V_FDOPEN  0xB8
%define V_FDSEL   0xBA
%define V_FDSTART 0xBC
%define V_ODS     0xC0
%define V_OSI     0xC2
%define V_PANEL   0xC4
%define VIS_CLASS 0x100
%define VIS_RES   5
%define VIS_CHUNK 0x22

%macro VIS_ENTER 0
 mov [es:V_ODS],ds
 mov [es:V_OSI],si
 push es
 pop ds
%endmacro
%macro FONT_ROW 3
 mov ax,0
 cmp word [V_FDSEL],%1
 jne %%normal
 mov ax,1
 mov al,15
 call set_text_color
 jmp %%text_done
%%normal:
 mov al,0
 call set_text_color
%%text_done:
 mov ax,0
 cmp word [V_FDSEL],%1
 jne %%area_normal
 mov ax,1
%%area_normal:
 call set_area
 mov ax,140
 mov bx,146+%1*28
 mov cx,420
 mov dx,bx
 add dx,24
 call fill_rect
 mov cx,%2
 mov dx,14
 mov ax,14
 call set_font
 mov ax,154
 mov bx,150+%1*28
 mov si,%3
 mov cx,8
 call draw_text
 mov ax,326
 mov bx,150+%1*28
 mov si,font_sample
 mov cx,font_sample_end-font_sample
 call draw_text
%endmacro

G1_METHOD 0x0a01, app_open
G1_METHOD 0x0a03, app_close
G1_METHOD 0x0004, meta_attach
G1_METHOD 0x0057, view_closed
vis_class_table:
 db 'G1VISCLS'
 dw 14
 dw 0x2071,0x0049,0x007b,0x00c3
 dw 0x0c10,0x0c11,0x0c12,0x0c13,0x0c14,0x0c15
 dw 0x0c20,0x0c21,0x0c22,0x0c23
 dw vis_draw,vis_exposed,vis_kbd_char,vis_start_select
 dw choose_berkeley,choose_roman,choose_sans,choose_mono,choose_next,choose_previous
 dw choose_table,choose_copy,choose_info,choose_help

app_open:
 push es
 pop ds
 mov word [V_FONT],FONT_DEFAULT
 mov word [V_FDOPEN],0
 mov word [V_FDSEL],0
 mov word [V_FDSTART],0
 mov word [V_PANEL],0
 mov di,PROCESS_CLASS
 KCALL 489
 retf

app_close:
 xor cx,cx
 retf

meta_attach:
 mov di,PROCESS_CLASS
 KCALL 489
 retf

choose_berkeley:
 VIS_ENTER
 mov word [V_FONT],0x0202
 jmp font_changed
choose_roman:
 VIS_ENTER
 mov word [V_FONT],0x1000
 jmp font_changed
choose_sans:
 VIS_ENTER
 mov word [V_FONT],0x1200
 jmp font_changed
choose_mono:
 VIS_ENTER
 mov word [V_FONT],0x1a00
font_changed:
 call redraw
 jmp vis_ret

choose_next:
 VIS_ENTER
 mov ax,1
 jmp font_step
choose_previous:
 VIS_ENTER
 mov ax,0xffff
font_step:
 call cycle_font_by
 call redraw
 jmp vis_ret

choose_table:
 VIS_ENTER
 mov word [V_PANEL],0
 call redraw
 jmp vis_ret
choose_info:
 VIS_ENTER
 mov word [V_PANEL],1
 call redraw
 jmp vis_ret
choose_help:
 VIS_ENTER
 mov word [V_PANEL],2
 call redraw
 jmp vis_ret
choose_copy:
 VIS_ENTER
 call copy_selected
 jmp vis_ret

cycle_font_by:
 ; AX is +1 for next and -1 for previous. The selectable font list is
 ; defined once in font_ids and is shared with the menu and picker overlay.
 push ax
 xor si,si
.find_font:
 cmp si,4
 jae .wrap
 mov bx,si
 shl bx,1
 mov dx,[cs:font_ids+bx]
 cmp dx,[V_FONT]
 je .found_font
 inc si
 jmp .find_font
.found_font:
 pop ax
 add si,ax
 and si,3
 jmp .set_font
.wrap:
 pop ax
 xor si,si
.set_font:
 mov bx,si
 shl bx,1
 mov ax,[cs:font_ids+bx]
 mov [V_FONT],ax
 ret

view_closed:
 mov word [V_WIN],0
 mov di,PROCESS_CLASS
 KCALL 489
 retf

vis_draw:
 VIS_ENTER
 mov word [V_WIN],1
 mov di,bp
 call paint_table
 jmp vis_ret

vis_exposed:
 VIS_ENTER
 mov word [V_WIN],1
 mov ax,0x0049
 jmp vis_super

vis_ret:
 mov si,[V_OSI]
 mov ds,[V_ODS]
 retf

vis_super:
 push ds
 pop es
 mov si,[V_OSI]
 mov ds,[V_ODS]
 mov di,VIS_CLASS
 KCALL 489
 retf

vis_kbd_char:
 VIS_ENTER
 cmp word [V_PANEL],0
 je .font_check
 cmp cl,27
 jne .panel_eat
 mov word [V_PANEL],0
 call redraw
 mov ax,0x8000
 jmp vis_ret
.panel_eat:
 mov ax,0x8000
 jmp vis_ret
.font_check:
 cmp word [V_FDOPEN],0
 jne .font_dialog
 cmp ch,0xff
 jne .ascii
 test dl,0x81
 jnz .pass
 cmp cl,0x90
 je .up
 cmp cl,0x91
 je .down
 cmp cl,0x92
 je .right
 cmp cl,0x93
 je .left
 jmp .pass
.ascii:
 mov al,cl
 or al,0x20
 cmp al,'f'
 je .font_open
 cmp al,'c'
 je .copy
 cmp al,' '
 je .copy
 jmp .pass
.up:
 mov ax,[V_SEL]
 sub ax,16
 jnc .move
 add ax,256
 jmp .move
.down:
 mov ax,[V_SEL]
 add ax,16
 and ax,0xff
 jmp .move
.right:
 mov ax,[V_SEL]
 inc ax
 and ax,0xff
 jmp .move
.left:
 mov ax,[V_SEL]
 dec ax
 and ax,0xff
.move:
 mov [V_SEL],ax
 call redraw
 mov ax,0x8000
 jmp vis_ret
.font_open:
 call font_dialog_open
 mov word [V_FDOPEN],1
 call redraw
 mov ax,0x8000
 jmp vis_ret
.copy:
 call copy_selected
 mov ax,0x8000
 jmp vis_ret
.font_dialog:
 cmp ch,0xff
 jne .font_ascii
 test dl,0x81
 jnz .font_eat
 cmp cl,0x90
 je .font_up
 cmp cl,0x91
 je .font_down
 cmp cl,0x94
 je .font_apply
 cmp cl,0x95
 je .font_cancel
 jmp .font_eat
.font_ascii:
 cmp cl,13
 je .font_apply
 cmp cl,27
 je .font_cancel
 jmp .font_eat
.font_up:
 mov ax,[V_FDSEL]
 or ax,ax
 jz .font_eat
 dec ax
 mov [V_FDSEL],ax
 call redraw
 jmp .font_eat
.font_down:
 mov ax,[V_FDSEL]
 inc ax
 cmp ax,4
 jae .font_eat
 mov [V_FDSEL],ax
 call redraw
 jmp .font_eat
.font_apply:
 mov bx,[V_FDSEL]
 shl bx,1
 mov ax,[cs:font_ids+bx]
 mov [V_FONT],ax
.font_cancel:
 mov word [V_FDOPEN],0
 call redraw
.font_eat:
 mov ax,0x8000
 jmp vis_ret
.pass:
 mov ax,0x007b
 jmp vis_super

vis_start_select:
 VIS_ENTER
 cmp word [V_PANEL],0
 je .font_dialog_check
 mov ax,0x8000
 jmp vis_ret
.font_dialog_check:
 cmp word [V_FDOPEN],0
 jne .font_row
 cmp cx,450
 jb .grid
 cmp cx,560
 jae .grid
 cmp dx,4
 jb .grid
 cmp dx,50
 jae .grid
 call font_dialog_open
 mov word [V_FDOPEN],1
 call redraw
 mov ax,0x8000
 jmp vis_ret
.grid:
 sub cx,GRID_X
 sub dx,GRID_Y
 cmp cx,0
 jl .pass
 cmp dx,0
 jl .pass
 cmp cx,512
 jae .pass
 cmp dx,320
 jae .pass
 mov ax,cx
 mov bl,CELL_W
 div bl
 mov [V_COL],al
 mov ax,dx
 mov bl,CELL_H
 div bl
 mov [V_ROW],al
 xor ax,ax
 mov al,[V_ROW]
 mov bl,16
 mul bl
 xor bx,bx
 mov bl,[V_COL]
 add ax,bx
 mov [V_SEL],ax
 call redraw
 mov ax,0x8000
 jmp vis_ret
.font_row:
 cmp cx,140
 jb .font_cancel
 cmp cx,420
 jae .font_cancel
 sub dx,146
 cmp dx,0
 jl .font_cancel
 cmp dx,112
 jae .font_cancel
 mov ax,dx
 mov bl,28
 div bl
 xor ah,ah
 cmp al,3
 ja .font_cancel
 mov [V_FDSEL],ax
 mov bx,ax
 shl bx,1
 mov ax,[cs:font_ids+bx]
 mov [V_FONT],ax
.font_cancel:
 mov word [V_FDOPEN],0
 call redraw
 mov ax,0x8000
 jmp vis_ret
.pass:
 mov ax,0x00c3
 jmp vis_super

font_dialog_open:
 mov word [V_FDSEL],0
 xor si,si
.find:
 cmp si,4
 jae .done
 mov bx,si
 shl bx,1
 mov ax,[cs:font_ids+bx]
 cmp ax,[V_FONT]
 je .found
 inc si
 jmp .find
.found:
 mov [V_FDSEL],si
.done:
 ret

copy_selected:
 mov al,[V_SEL]
 cmp al,0x20
 jb .copy_done
 cmp al,0x7f
 je .copy_done
 mov [cs:charbuf],al
 push ds
 push cs
 pop ds
 mov si,charbuf
 mov cx,1
 mov dx,clip_name
 call g1_clip_text
 pop ds
.copy_done:
 ret

redraw:
 cmp word [V_WIN],0
 je .done
 push word [V_ODS]
 push word [V_OSI]
 call begin_direct
 jc .restore
 ; Draw through the same MSG_VIS_DRAW path used by normal window exposes.
 ; This lets the view's update region and clipping remain under GEOS control.
 push di
 push bp
 mov bp,di
 mov bx,VIS_RES
 KCALL 150
 mov si,VIS_CHUNK
 mov ax,0x2071
 xor cx,cx
 mov di,0x8080
 KCALL 169
 pop bp
 pop di
 KCALL 212
.restore:
 pop word [V_OSI]
 pop word [V_ODS]
.done:
 ret

begin_direct:
 push si
 push bp
 mov bx,VIS_RES
 KCALL 150
 mov si,VIS_CHUNK
 mov ax,0x2063
 mov di,0x8080
 KCALL 169
 mov di,bp
 pop bp
 pop si
 or di,di
 jz .no
 clc
 ret
.no:
 stc
 ret

; AX/BX = point, DS:SI = bytes, CX = byte count. GState remains in DI.
draw_text:
 push ds
 push cs
 pop ds
 push di
 KCALL 330                       ; GrDrawText
 pop di
 pop ds
 ret

set_area:
 push di
 KCALL 355                       ; GrSetAreaColor
 pop di
 ret

set_text_color:
 push di
 KCALL 359                       ; GrSetTextColor
 pop di
 ret

set_text_style:
 push di
 KCALL 362                       ; GrSetTextStyle
 pop di
 ret

set_font:
 push di
 KCALL 366                       ; GrSetFont
 pop di
 ret

fill_rect:
 push di
 KCALL 336                       ; GrFillRect
 pop di
 ret

paint_table:
 ; white window background
 mov ax,15
 call set_area
 xor ax,ax
 xor bx,bx
 mov cx,560
 mov dx,450
 call fill_rect

 ; blue heading
 mov ax,1
 call set_area
 mov ax,12
 mov bx,10
 mov cx,548
 mov dx,42
 call fill_rect
 mov cx,[V_FONT]
 mov dx,18
 mov ax,18
 call set_font
 mov ax,0x0020
 call set_text_style
 mov al,15
 call set_text_color
 mov ax,24
 mov bx,17
 mov si,title
 mov cx,title_end-title
 call draw_text
 mov ax,0xff00
 call set_text_style
 cmp word [V_PANEL],1
 je .info_page
 cmp word [V_PANEL],2
 je .help_page
 ; The grid shows glyphs only; the selected byte value is shown below.
 mov cx,[V_FONT]
 mov dx,8
 mov ax,8
 call set_font
 mov word [V_CODE],0
.cell:
 mov ax,[V_CODE]
 mov bl,16
 div bl                          ; AL=row, AH=column
 xor bx,bx
 mov bl,al
 mov cx,bx
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl cx,1
 shl cx,1
 add bx,cx                       ; row * 20
 add bx,GRID_Y
 mov [V_ROW],bx
 xor bx,bx
 mov bl,ah
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1                       ; column * 32
 add bx,GRID_X
 mov [V_COL],bx

 mov ax,[V_CODE]
 cmp ax,[V_SEL]
 jne .normal
 mov ax,1
 call set_area
 mov ax,[V_COL]
 mov bx,[V_ROW]
 mov cx,ax
 add cx,CELL_W-1
 mov dx,bx
 add dx,CELL_H-1
 call fill_rect
 mov ax,15
 call set_text_color
 jmp .code
.normal:
 mov ax,0
 call set_text_color
.code:
; C0 controls and DEL have no printable glyph cell; codes appear below.
 mov ax,[V_CODE]
 cmp ax,0x20
 jb .next
 cmp ax,0x7f
 je .next
 mov ax,[V_CODE]
 mov [cs:charbuf],al
 mov cx,[V_FONT]
 mov dx,14
 mov ax,10
 call set_font
 mov ax,[V_COL]
 add ax,9
 mov bx,[V_ROW]
 add bx,2
 mov si,charbuf
 mov cx,1
 push ds
 push cs
 pop ds
 call draw_text
 pop ds
 mov cx,[V_FONT]
 mov dx,8
 mov ax,8
 call set_font
.next:
 inc word [V_CODE]
 cmp word [V_CODE],256
 jb .cell

 ; Selection status beneath the grid.
 mov ax,0
 call set_text_color
 mov cx,FONT_DEFAULT
 mov dx,12
 mov ax,12
 call set_font
 mov si,status
 mov ax,16
 mov bx,390
 mov cx,status_end-status
 call draw_text
 mov ax,[V_SEL]
 mov bl,16
 div bl
 xor bx,bx
 mov bl,al
 mov al,[cs:hexchars+bx]
 mov [cs:codebuf],al
 xor bx,bx
 mov bl,ah
 mov al,[cs:hexchars+bx]
 mov [cs:codebuf+1],al
 mov ax,106
 mov bx,390
 mov si,codebuf
 mov cx,2
 push ds
 push cs
 pop ds
 call draw_text
 pop ds
 mov al,[V_SEL]
 cmp al,0x20
 jb .status_done
 cmp al,0x7f
 je .status_done
 mov [cs:charbuf],al
 mov cx,[V_FONT]
 mov dx,22
 mov ax,22
 ; The four current choices are text fonts. If a future symbol/LED
 ; font is added, keep its name readable with the Berkeley fallback.
 cmp cx,0x0202
 je .preview_font
 cmp cx,0x1000
 je .preview_font
 cmp cx,0x1200
 je .preview_font
 cmp cx,0x1a00
 je .preview_font
 mov cx,FONT_DEFAULT
.preview_font:
 call set_font
 mov ax,144
 mov bx,384
 mov si,charbuf
 mov cx,1
 push ds
 push cs
 pop ds
 call draw_text
 pop ds
 .status_done:
 mov ax,0
 call set_text_color
 mov cx,FONT_DEFAULT
 mov dx,10
 mov ax,10
 call set_font
 mov si,build_stamp
 mov ax,16
 mov bx,420
 mov cx,build_stamp_end-build_stamp
 call draw_text
 mov si,font_label
 mov ax,150
 mov bx,420
 mov cx,font_label_end-font_label
 call draw_text
 mov si,font_berkeley
 cmp word [V_FONT],0x0202
 je .font_name
 mov si,font_roman
 cmp word [V_FONT],0x1000
 je .font_name
 mov si,font_sans
 cmp word [V_FONT],0x1200
 je .font_name
 mov si,font_mono
.font_name:
 mov cx,[V_FONT]
 cmp cx,0x0202
 je .font_name_size
 cmp cx,0x1000
 je .font_name_size
 cmp cx,0x1200
 je .font_name_size
 cmp cx,0x1a00
 je .font_name_size
 mov cx,FONT_DEFAULT
.font_name_size:
 mov dx,20
 mov ax,20
 call set_font
 mov ax,208
 mov bx,416
 mov cx,8
 call draw_text
 cmp word [V_FDOPEN],0
 je .no_font_dialog
 call paint_font_dialog
.no_font_dialog:
 ret

.info_page:
 call paint_info_page
 ret
.help_page:
 call paint_help_page
 ret

paint_info_page:
 mov cx,FONT_DEFAULT
 mov dx,12
 mov cx,12
 call set_font
 mov ax,24
 mov bx,78
 mov si,info_line1
 mov cx,info_line1_end-info_line1
 call draw_text
 mov bx,108
 mov si,info_line2
 mov cx,info_line2_end-info_line2
 call draw_text
 mov bx,138
 mov si,info_line3
 mov cx,info_line3_end-info_line3
 call draw_text
 mov bx,168
 mov si,info_line4
 mov cx,info_line4_end-info_line4
 call draw_text
 ret

paint_help_page:
 mov cx,FONT_DEFAULT
 mov dx,12
 mov cx,12
 call set_font
 mov ax,24
 mov bx,78
 mov si,help_line1
 mov cx,help_line1_end-help_line1
 call draw_text
 mov bx,108
 mov si,help_line2
 mov cx,help_line2_end-help_line2
 call draw_text
 mov bx,138
 mov si,help_line3
 mov cx,help_line3_end-help_line3
 call draw_text
 mov bx,168
 mov si,help_line4
 mov cx,help_line4_end-help_line4
 call draw_text
 mov bx,198
 mov si,help_line5
 mov cx,help_line5_end-help_line5
 call draw_text
 ret

paint_font_dialog:
 mov ax,8
 call set_area
 mov ax,126
 mov bx,108
 mov cx,434
 mov dx,338
 call fill_rect
 mov ax,0
 call set_text_color
 mov cx,[V_FONT]
 mov dx,12
 mov ax,12
 call set_font
 mov si,font_title
 mov ax,148
 mov bx,120
 mov cx,font_title_end-font_title
 call draw_text
 FONT_ROW 0,0x0202,font_berkeley
 FONT_ROW 1,0x1000,font_roman
 FONT_ROW 2,0x1200,font_sans
 FONT_ROW 3,0x1a00,font_mono
 mov cx,[V_FONT]
 mov dx,10
 mov ax,10
 call set_font
 mov si,font_hint
 mov ax,148
 mov bx,267
 mov cx,font_hint_end-font_hint
 call draw_text
 ret
hexchars: db '0123456789ABCDEF'
title: db 'Zeichensatz Tabelle - GEOS 1'
title_end:
status: db 'Auswahl: 0x'
status_end:
codebuf: db '00'
charbuf: db 0
clip_name: db 'Zeichensatz Tabelle',0
font_title: db 'Schriftart auswaehlen'
font_title_end:
build_stamp: db 'Build: 20261126-FONT12'
build_stamp_end:
font_label: db 'Schrift:'
font_label_end:
font_hint: db 'Pfeile + Enter bestaetigen; Esc schliesst'
font_hint_end:
font_berkeley: db 'Berkeley'
font_roman: db 'Roman   '
font_sans: db 'Sans    '
font_mono: db 'Mono    '
font_sample: db 'Aa 0123'
font_sample_end:
info_line1: db 'Zeichensatz Tabelle fuer GeoWorks 1'
info_line1_end:
info_line2: db 'Das Raster zeigt GEOS-Zeichencodes 00 bis FF.'
info_line2_end:
info_line3: db 'Nur druckbare Zeichen koennen kopiert werden.'
info_line3_end:
info_line4: db 'Die Tabelle ist keine Unicode-Zeichentabelle.'
info_line4_end:
help_line1: db 'Zelle anklicken oder mit Pfeiltasten auswaehlen.'
help_line1_end:
help_line2: db 'C oder Leertaste kopiert das ausgewaehlte Zeichen.'
help_line2_end:
help_line3: db 'Im Menue Schrift eine Schriftart waehlen.'
help_line3_end:
help_line4: db 'Naechste/Vorige Schrift blaettert durch die Liste.'
help_line4_end:
help_line5: db 'Esc kehrt zur Zeichentabelle zurueck.'
help_line5_end:
font_ids: dw 0x0202,0x1000,0x1200,0x1a00

%include "g1clip.inc"
G1_FINISH






