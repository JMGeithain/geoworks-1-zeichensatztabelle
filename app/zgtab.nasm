; SPDX-License-Identifier: Apache-2.0
; Copyright 2026 Johannes Möller, Syhra
; Zeichensatz Tabelle for the Ensemble 1.2 / GeoWorks 1.28 profile.
; 16 x 16 GEOS byte table, mouse/keyboard selection, clipboard copy.
%include "ensemble12.inc"
%define PROCESS_CLASS 0x40
%define FONT_DEFAULT 0x0202         ; Berkeley bitmap font
%define FONT_UI      0x0A00         ; Bison, compact labels and information
%define GRID_X 16
%define GRID_Y 60
; Glyph origins advance 32 points horizontally and 16 vertically.
%define CELL_W 32
%define CELL_H 16

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
%define V_FDROW   0xC6
%define V_FDINDEX 0xC8
%define V_COPY   0xCA
%define VIS_CLASS 0x100
%define VIS_RES   11
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
 dw 13
 dw 0x2071,0x0049,0x007b,0x00c3
 dw 0x0c10,0x0c11,0x0c12,0x0c13
 dw 0x0c20,0x0c21,0x0c22,0x0c23,0x0c16
 dw vis_draw,vis_exposed,vis_kbd_char,vis_start_select
 dw choose_berkeley,choose_roman,choose_sans,choose_mono
 dw choose_table,choose_copy,choose_info,choose_help,choose_all_fonts

app_open:
 push es
 pop ds
 mov word [V_FONT],FONT_DEFAULT
 mov word [V_SEL],0x41
 mov word [V_COPY],0
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
 call redraw
 jmp vis_ret
choose_all_fonts:
 VIS_ENTER
 call font_dialog_open
 mov word [V_FDOPEN],1
 call redraw
 jmp vis_ret

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
 call redraw
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
 call font_keep_visible
 call redraw
 jmp .font_eat
.font_down:
 mov ax,[V_FDSEL]
 inc ax
 cmp ax,font_count
 jae .font_eat
 mov [V_FDSEL],ax
 call font_keep_visible
 call redraw
 jmp .font_eat
.font_apply:
 mov bx,[V_FDSEL]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 mov ax,[cs:font_records+bx]
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
.copy_grid_check:
 cmp cx,340
 jb .grid
 cmp cx,540
 jae .grid
 cmp dx,18
 jb .grid
 cmp dx,40
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
 cmp dx,256
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
 cmp cx,410
 jb .font_row_area
 cmp cx,434
 jae .font_row_area
 cmp dx,146
 jb .font_row_area
 cmp dx,162
 jae .font_scroll_down
 cmp word [V_FDSTART],0
 je .font_handled
 dec word [V_FDSTART]
 call redraw
 jmp .font_handled
.font_scroll_down:
 cmp dx,290
 jb .font_row_area
 cmp dx,306
 jae .font_row_area
 mov ax,[V_FDSTART]
 cmp ax,font_count-10
 jae .font_handled
 inc word [V_FDSTART]
 call redraw
 jmp .font_handled
.font_row_area:
 cmp cx,140
 jb .font_cancel
 cmp cx,420
 jae .font_cancel
 cmp dx,306
 jae .font_buttons
 sub dx,146
 cmp dx,0
 jl .font_cancel
 cmp dx,160
 jae .font_cancel
 mov ax,dx
 mov bl,16
 div bl
 xor ah,ah
 add ax,[V_FDSTART]
 cmp ax,font_count
 jae .font_handled
 mov [V_FDSEL],ax
 call redraw
 jmp .font_handled
.font_handled:
 mov ax,0x8000
 jmp vis_ret
.font_buttons:
 cmp dx,342
 jb .font_cancel
 cmp dx,374
 jae .font_cancel
 cmp cx,154
 jb .font_cancel
 cmp cx,246
 jae .font_close_button
 mov bx,[V_FDSEL]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 mov ax,[cs:font_records+bx]
 mov [V_FONT],ax
 jmp .font_cancel
.font_close_button:
 cmp cx,260
 jb .font_cancel
 cmp cx,352
 jae .font_cancel
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
 cmp si,font_count
 jae .done
 mov bx,si
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 mov ax,[cs:font_records+bx]
 cmp ax,[V_FONT]
 je .found
 inc si
 jmp .find
.found:
 mov [V_FDSEL],si
.done:
 mov word [V_FDSTART],0
 mov ax,[V_FDSEL]
 cmp ax,5
 jb .start_ready
 sub ax,5
 mov [V_FDSTART],ax
.start_ready:
 ret

font_keep_visible:
 mov ax,[V_FDSEL]
 cmp ax,[V_FDSTART]
 jae .check_bottom
 mov [V_FDSTART],ax
 ret
.check_bottom:
 mov dx,[V_FDSTART]
 add dx,10
 cmp ax,dx
 jb .done
 sub ax,9
 mov [V_FDSTART],ax
.done:
 ret

copy_selected:
 mov al,[V_SEL]
 mov byte [V_COPY],2
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
 jc .copy_failed
 mov byte [V_COPY],1
 jmp .copy_done
.copy_failed:
 mov byte [V_COPY],3
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
 mov cx,540
 mov dx,350
 call fill_rect
 cmp word [V_PANEL],1
 je .info_page
 cmp word [V_PANEL],2
 je .help_page
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov ax,16
 mov bx,4
 mov si,copy_field_label
 mov cx,copy_field_label_end-copy_field_label
 call draw_text
 ; Put the selected byte code directly below the enlarged character.
 mov si,status
 mov ax,16
 mov bx,42
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
 mov ax,94
 mov bx,42
 mov si,codebuf
 mov cx,2
 push ds
 push cs
 pop ds
 call draw_text
 pop ds
 ; The grid shows glyphs only; the selected byte value is shown above.
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
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
                                  ; row * 16
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
 mov dx,12
 mov ax,8
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

 ; Frame the complete character table with the already verified fill call.
 mov ax,0
 call set_area
 mov ax,GRID_X-2
 mov bx,GRID_Y-2
 mov cx,GRID_X+16*CELL_W+1
 mov dx,GRID_Y-1
 call fill_rect
 mov ax,GRID_X-2
 mov bx,GRID_Y+16*CELL_H+1
 mov cx,GRID_X+16*CELL_W+1
 mov dx,GRID_Y+16*CELL_H+2
 call fill_rect
 mov ax,GRID_X-2
 mov bx,GRID_Y-1
 mov cx,GRID_X-1
 mov dx,GRID_Y+16*CELL_H+2
 call fill_rect
 mov ax,GRID_X+16*CELL_W
 mov bx,GRID_Y-1
 mov cx,GRID_X+16*CELL_W+1
 mov dx,GRID_Y+16*CELL_H+2
 call fill_rect

 ; Keep errors below the grid; successful copies are reported above.
 mov ax,0
 call set_text_color
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov al,[V_COPY]
 or al,al
 jz .copy_status_done
 cmp al,1
 je .copy_success
 cmp al,2
 je .copy_control
 mov si,copy_failed
 mov cx,copy_failed_end-copy_failed
 jmp .copy_status_draw
.copy_success:
 mov ax,12
 call set_text_color
 mov si,copy_success
 mov cx,copy_success_end-copy_success
 mov ax,480
 mov bx,4
 call draw_text
 mov ax,0
 call set_text_color
 jmp .copy_status_done
.copy_control:
 mov si,copy_control
 mov cx,copy_control_end-copy_control
.copy_status_draw:
 mov ax,160
 mov bx,327
 call draw_text
.copy_status_done:
 mov al,[V_SEL]
 cmp al,0x20
 jb .status_done
 cmp al,0x7f
 je .status_done
 mov [cs:charbuf],al
 mov cx,[V_FONT]
 mov dx,22
 mov ax,22
 call set_font
 mov ax,26
 mov bx,22
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
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov si,font_label
 mov ax,310
 mov bx,4
 mov cx,font_label_end-font_label
 call draw_text
 xor bx,bx
.font_name_find:
 cmp bx,font_count*32
 jae .font_name_fallback
 mov ax,[V_FONT]
 cmp ax,[cs:font_records+bx]
 je .font_name_found
 add bx,32
 jmp .font_name_find
.font_name_found:
 mov [V_FDINDEX],bx
 mov cx,[V_FONT]
 test byte [cs:font_records+bx+22],1
 jz .font_name_ready
 mov cx,FONT_DEFAULT
 jmp .font_name_ready
.font_name_fallback:
 mov word [V_FDINDEX],0xffff
 mov cx,FONT_DEFAULT
.font_name_ready:
 mov dx,18
 mov ax,18
 call set_font
 cmp word [V_FDINDEX],0xffff
 je .draw_fallback_name
 mov si,[V_FDINDEX]
 add si,font_records+2
 mov cx,20
 jmp .draw_font_name
.draw_fallback_name:
 mov si,font_berkeley
 mov cx,font_berkeley_end-font_berkeley
.draw_font_name:
 mov ax,310
 mov bx,22
 call draw_text
 cmp word [V_FDINDEX],0xffff
 je .no_dos_filename
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov si,dos_file_label
 mov ax,310
 mov bx,42
 mov cx,dos_file_label_end-dos_file_label
 call draw_text
 mov bx,[V_FDINDEX]
 shr bx,1
 shr bx,1
 shr bx,1
 shr bx,1
 shr bx,1                       ; record byte offset -> record index
 mov cx,bx
 shl bx,1
 shl bx,1
 shl bx,1                       ; index * 8
 shl cx,1
 shl cx,1                       ; index * 4
 add bx,cx                      ; index * 12
 add bx,font_dos_names
 mov si,bx
 mov ax,414
 mov bx,42
 mov cx,12
 call draw_text
.no_dos_filename:
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
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
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
 mov bx,198
 mov si,info_line5
 mov cx,info_line5_end-info_line5
 call draw_text
 mov bx,228
 mov si,build_stamp
 mov cx,build_stamp_end-build_stamp
 call draw_text
 ret

paint_help_page:
 ; Follow GeoZeit's help/info page hierarchy: Berkeley title and body,
 ; with a clear 18-point heading and comfortably spaced 12-point text.
 mov cx,FONT_DEFAULT
 mov dx,18
 mov ax,18
 call set_font
 mov ax,24
 mov bx,42
 mov si,help_title
 mov cx,help_title_end-help_title
 call draw_text
 mov cx,FONT_DEFAULT
 mov dx,12
 mov ax,12
 call set_font
 mov ax,24
 mov bx,82
 mov si,help_line1
 mov cx,help_line1_end-help_line1
 call draw_text
 mov bx,112
 mov si,help_line2
 mov cx,help_line2_end-help_line2
 call draw_text
 mov bx,142
 mov si,help_line3
 mov cx,help_line3_end-help_line3
 call draw_text
 mov bx,172
 mov si,help_line4
 mov cx,help_line4_end-help_line4
 call draw_text
 mov bx,202
 mov si,help_line5
 mov cx,help_line5_end-help_line5
 call draw_text
 ret

paint_font_dialog:
 ; Compact modal picker in the style of GeoWrite's "Weitere Schriften".
 mov ax,8
 call set_area
 mov ax,126
 mov bx,108
 mov cx,434
 mov dx,388
 call fill_rect
 mov ax,0
 call set_text_color
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov si,font_title
 mov ax,205
 mov bx,120
 mov cx,font_title_end-font_title
 call draw_text

 ; Font list background and ten visible entries.
 mov ax,15
 call set_area
 mov ax,140
 mov bx,146
 mov cx,410
 mov dx,306
 call fill_rect
 mov word [V_FDROW],0
.list_row:
 mov ax,[V_FDROW]
 cmp ax,10
 jae .list_done
 mov ax,[V_FDSTART]
 add ax,[V_FDROW]
 cmp ax,font_count
 jae .list_next
 mov [V_FDINDEX],ax
 cmp ax,[V_FDSEL]
 jne .row_text_normal
 mov ax,1
 call set_area
 mov ax,140
 mov bx,[V_FDROW]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 add bx,146
 mov cx,408
 mov dx,bx
 add dx,15
 call fill_rect
 mov al,15
 call set_text_color
 jmp .row_draw
.row_text_normal:
 mov al,0
 call set_text_color
.row_draw:
 mov bx,[V_FDINDEX]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 add bx,font_records+2
 mov si,bx
 mov ax,148
 mov bx,[V_FDROW]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 add bx,149
 mov cx,20
 call draw_text
 mov ax,15
 call set_area
.list_next:
 inc word [V_FDROW]
 jmp .list_row
.list_done:

 ; Scroll track and arrow buttons.
 mov ax,7
 call set_area
 mov ax,410
 mov bx,146
 mov cx,432
 mov dx,306
 call fill_rect
 mov ax,0
 call set_text_color
 mov si,up_arrow
 mov ax,417
 mov bx,157
 mov cx,1
 call draw_text
 mov si,down_arrow
 mov ax,417
 mov bx,301
 mov cx,1
 call draw_text

 ; Preview the highlighted typeface, including symbol and LED fonts.
 mov bx,[V_FDSEL]
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 shl bx,1
 mov cx,[cs:font_records+bx]
 mov dx,18
 mov ax,18
 call set_font
 mov si,font_sample
 mov ax,146
 mov bx,330
 mov cx,font_sample_end-font_sample
 call draw_text

 ; GeoWrite-style Apply and Close buttons.
 mov ax,7
 call set_area
 mov ax,154
 mov bx,342
 mov cx,246
 mov dx,374
 call fill_rect
 mov ax,260
 mov bx,342
 mov cx,352
 mov dx,374
 call fill_rect
 mov ax,0
 call set_text_color
 mov cx,FONT_UI
 mov dx,10
 mov ax,10
 call set_font
 mov si,apply_button
 mov ax,162
 mov bx,352
 mov cx,apply_button_end-apply_button
 call draw_text
 mov si,close_button
 mov ax,271
 mov bx,352
 mov cx,close_button_end-close_button
 call draw_text
 mov si,font_hint
 mov ax,146
 mov bx,382
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
font_title: db 'Weitere Schriften'
font_title_end:
build_stamp: db 'Build: 20261126-VGA10-MENUHELP'
build_stamp_end:
font_label: db 'Schriftart:'
font_label_end:
dos_file_label: db 'DOS-Datei:'
dos_file_label_end:
font_hint: db 'Pfeile: Auswahl; Enter: Uebernehmen; Esc: Schliessen'
font_hint_end:
apply_button: db 'Uebernehmen'
apply_button_end:
close_button: db 'Schliessen'
close_button_end:
font_berkeley: db 'Berkeley'
font_berkeley_end:
font_roman: db 'Roman   '
font_sans: db 'Sans    '
font_mono: db 'Mono    '
copy_field_label: db 'Zu kopierende Zeichen:'
copy_field_label_end:
font_sample: db 'Aa 0123'
font_sample_end:
up_arrow: db '^'
down_arrow: db 'v'
copy_success: db 'Kopiert'
copy_success_end:
copy_control: db 'Steuerzeichen nicht kopierbar'
copy_control_end:
copy_failed: db 'Clipboard-Fehler'
copy_failed_end:
info_line1: db 'Zeichensatztabelle Version 1.0'
info_line1_end:
info_line2: db 'f',0x81,'r GeoWorks 1.*'
info_line2_end:
info_line3: db '2026 (c) Johannes M',0x94,'ller, Syhra'
info_line3_end:
info_line4: db 'Apache-Lizenz 2.0'
info_line4_end:
info_line5: db 'GEOS-Zeichencodes 00 bis FF (kein Unicode).'
info_line5_end:
help_title: db 'Hilfe'
help_title_end:
help_line1: db 'Zeichen mit Maus oder Pfeiltasten auswaehlen.'
help_line1_end:
help_line2: db 'Vorschau und Hex-Code zeigen die Auswahl.'
help_line2_end:
help_line3: db 'Kopieren legt druckbare Zeichen in die Ablage.'
help_line3_end:
help_line4: db 'Weitere Schriften wechselt die Schriftart.'
help_line4_end:
help_line5: db 'Steuercodes 00-1F und 7F sind nicht kopierbar.'
help_line5_end:
%include "fontlist.inc"

%include "g1clip.inc"
G1_FINISH






