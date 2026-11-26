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
G1_METHOD 0x0049, view_exposed
G1_METHOD 0x007b, kbd_char
G1_METHOD 0x00c3, mouse_select

app_open:
 push es
 pop ds
 mov word [V_FONT],FONT_DEFAULT
 mov word [V_FDOPEN],0
 mov word [V_FDSEL],0
 mov word [V_FDSTART],0
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

view_closed:
 mov word [V_WIN],0
 mov di,PROCESS_CLASS
 KCALL 489
 retf

view_exposed:
 mov [V_WIN],cx
 mov di,cx
 KCALL 211                       ; GrCreateState
 KCALL 446                       ; GrBeginUpdate
 call paint_table
 KCALL 447                       ; GrEndUpdate
 KCALL 212                       ; GrDestroyState
 retf

kbd_char:
 cmp word [V_FDOPEN],0
 jne .font_dialog
 cmp ch,0xff
 jne .ascii
 test dl,0x81                    ; ignore releases and state keys
 jnz .pass
 cmp cl,0x90                     ; up
 je .up
 cmp cl,0x91                     ; down
 je .down
 cmp cl,0x92                     ; right
 je .right
 cmp cl,0x93                     ; left
 je .left
 jmp .pass
.ascii:
 mov al,cl
 or al,0x20
 cmp al,'c'
 je .copy
 cmp al,' '
 je .copy
 cmp al,'f'
 je .font_open
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
 retf
.font_open:
 call font_dialog_open
 mov word [V_FDOPEN],1
 call redraw
 retf
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
 cmp ax,[V_FDSTART]
 jae .font_up_draw
 mov [V_FDSTART],ax
.font_up_draw:
 call redraw
 jmp .font_eat
.font_down:
 mov ax,[V_FDSEL]
 inc ax
 cmp ax,4
 jae .font_eat
 mov [V_FDSEL],ax
 mov bx,[V_FDSTART]
 add bx,4
 cmp ax,bx
 jb .font_down_draw
 sub ax,3
 mov [V_FDSTART],ax
.font_down_draw:
 call redraw
 jmp .font_eat
.font_apply:
 mov bx,[V_FDSEL]
 shl bx,1
 mov ax,[cs:font_ids+bx]
 mov [V_FONT],ax
 mov word [V_FDOPEN],0
 call redraw
 jmp .font_eat
.font_cancel:
 mov word [V_FDOPEN],0
 call redraw
.font_eat:
 mov ax,0x8000
 retf
.copy:
 mov al,[V_SEL]
 cmp al,0x20
 jb .pass
 cmp al,0x7f
 je .pass
 mov [cs:charbuf],al
 push ds
 push cs
 pop ds
 mov si,charbuf
 mov cx,1
 mov dx,clip_name
 call g1_clip_text
 pop ds
 retf
.pass:
 mov di,PROCESS_CLASS
 KCALL 489
 retf

mouse_select:
 cmp word [V_FDOPEN],0
 jne .font_mouse
 cmp cx,450
 jb .grid_mouse
 cmp cx,560
 jae .grid_mouse
 cmp dx,4
 jb .grid_mouse
 cmp dx,50
 jae .grid_mouse
 mov word [V_FDOPEN],1
 mov word [V_FDSEL],0
 call redraw
 mov ax,0x8000
 retf
.grid_mouse:
 ; CX,DX are the pointer coordinates in the document view.
 sub cx,GRID_X
 sub dx,GRID_Y
 cmp cx,0
 jl .ignored
 cmp dx,0
 jl .ignored
 cmp cx,512
 jae .ignored
 cmp dx,320
 jae .ignored
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
.ignored:
 mov ax,0x8000                  ; MRF_PROCESSED
 retf
.font_mouse:
 cmp cx,140
 jb .font_mouse_close
 cmp cx,420
 jae .font_mouse_close
 sub dx,146
 cmp dx,0
 jl .font_mouse_close
 cmp dx,112
 jae .font_mouse_close
 mov ax,dx
 mov bl,28
 div bl
 xor ah,ah
 cmp al,3
 ja .font_mouse_close
 cmp ax,3
 ja .font_mouse_close
 mov [V_FDSEL],ax
 mov bx,ax
 shl bx,1
 mov ax,[cs:font_ids+bx]
 mov [V_FONT],ax
.font_mouse_close:
 mov word [V_FDOPEN],0
 call redraw
 mov ax,0x8000
 retf

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
redraw:
 cmp word [V_WIN],0
 je .done
 mov di,[V_WIN]
 KCALL 211
 KCALL 446
 call paint_table
 KCALL 447
 KCALL 212
.done:
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
 mov ax,24
 mov bx,17
 mov si,title
 mov cx,title_end-title
 call draw_text
 mov si,font_button
 mov ax,486
 mov bx,18
 mov cx,font_button_end-font_button
 call draw_text

 ; table grid: every cell shows its two-digit GEOS code. Printable values
 ; additionally show the actual glyph in the selected font.
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
 mov ax,[V_CODE]
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
 mov ax,[V_COL]
 add ax,2
 mov bx,[V_ROW]
 add bx,2
 mov si,codebuf
 mov cx,2
 push ds
 push cs
 pop ds
 call draw_text
 pop ds

 ; C0 controls and DEL have no printable glyph cell.
 mov ax,[V_CODE]
 cmp ax,0x20
 jb .next
 cmp ax,0x7f
 je .next
 mov ax,[V_CODE]
 mov [cs:charbuf],al
 mov cx,[V_FONT]
 mov dx,10
 mov ax,10
 call set_font
 mov ax,[V_COL]
 add ax,18
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
 mov cx,[V_FONT]
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
 mov dx,18
 mov ax,18
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
 mov cx,[V_FONT]
 mov dx,10
 mov ax,10
 call set_font
 mov si,build_stamp
 mov ax,16
 mov bx,420
 mov cx,build_stamp_end-build_stamp
 call draw_text
 cmp word [V_FDOPEN],0
 je .no_font_dialog
 call paint_font_dialog
.no_font_dialog:
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
font_button: db 'Schrift F'
font_button_end:
font_title: db 'Schriftart auswaehlen'
font_title_end:
build_stamp: db 'Build: 20261126-FONT4'
build_stamp_end:
font_hint: db 'Pfeile + Enter bestaetigen; Esc schliesst'
font_hint_end:
font_berkeley: db 'Berkeley'
font_roman: db 'Roman   '
font_sans: db 'Sans    '
font_mono: db 'Mono    '
font_sample: db 'Aa 0123'
font_sample_end:
font_ids: dw 0x0202,0x1000,0x1200,0x1a00

%include "g1clip.inc"
G1_FINISH





