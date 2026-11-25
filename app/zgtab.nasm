; SPDX-License-Identifier: MIT
; Copyright 2026 Johannes Möller
; Zeichensatz Tabelle for the Ensemble 1.2 / GeoWorks 1.28 profile.
; 16 x 16 GEOS byte table, mouse/keyboard selection, clipboard copy.
%include "ensemble12.inc"
%define PROCESS_CLASS 0x40
%define FONT_ID 0x0202              ; Berkeley bitmap font
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
 test dl,0x81                    ; ignore releases and state keys
 jnz .pass
 cmp ch,0xff
 jne .ascii
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
.copy:
 mov al,[V_SEL]
 cmp al,0x20
 jb .pass
 cmp al,0x7f
 je .pass
 mov [charbuf],al
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
 mov cx,FONT_ID
 mov dx,18
 mov ax,18
 call set_font
 mov ax,24
 mov bx,17
 mov si,title
 mov cx,title_end-title
 call draw_text

 ; table grid: every cell shows its two-digit GEOS code. Printable values
 ; additionally show the actual glyph in Berkeley at 12 points.
 mov cx,FONT_ID
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
 mov [codebuf],al
 xor bx,bx
 mov bl,ah
 mov al,[cs:hexchars+bx]
 mov [codebuf+1],al
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
 mov [charbuf],al
 mov cx,FONT_ID
 mov dx,12
 mov ax,12
 call set_font
 mov ax,[V_COL]
 add ax,13
 mov bx,[V_ROW]
 add bx,8
 mov si,charbuf
 mov cx,1
 push ds
 push cs
 pop ds
 call draw_text
 pop ds
 mov cx,FONT_ID
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
 mov cx,FONT_ID
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
 mov [codebuf],al
 xor bx,bx
 mov bl,ah
 mov al,[cs:hexchars+bx]
 mov [codebuf+1],al
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
 mov [charbuf],al
 mov cx,FONT_ID
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
 ret

hexchars: db '0123456789ABCDEF'
title: db 'Zeichensatz Tabelle - GEOS 1'
title_end:
status: db 'Auswahl: 0x'
status_end:
codebuf: db '00'
charbuf: db 0
clip_name: db 'Zeichensatz Tabelle',0

%include "g1clip.inc"
G1_FINISH
