; SPDX-License-Identifier: Apache-2.0
; Text-to-clipboard helper for the observed Ensemble 1.2 / GeoWorks 1.28 ABI.
; Adapted from JMGeithain/geoworks-1-geozeit (app/g1clip.inc).
; DS:SI = GEOS text, CX = length, CS:DX = item name; CF signals failure.
g1_clip_text:
 push bx
 push cx
 push dx
 push si
 push di
 push bp
 push ds
 push es
 sub sp,16
 mov bp,sp
 mov [bp+0],ds
 mov [bp+2],si
 mov [bp+4],cx
 mov [bp+6],dx
 push bp
 LC 0,135
 pop bp
 mov [bp+8],bx
 mov ax,0x24
 mov cl,0x50
 mov ch,0x60
 KCALL 0
 jnc .text_block
 jmp .fail
.text_block:
 mov [bp+10],bx
 mov ds,ax
 mov dx,0x24
 xor ax,ax
 mov cl,0x80
 mov ch,0x10
 push bp
 KCALL 24
 pop bp
 xor ax,ax
 xor cx,cx
 push bp
 KCALL 25
 pop bp
 mov [0x10],ax
 mov word [0x12],0
 mov word [0x14],0
 mov word [0x16],0
 mov word [0x18],0
 mov cx,[bp+4]
 inc cx                              ; GEOS text data is NUL terminated
 push bp
 KCALL 28
 pop bp
 mov bx,[0x10]
 mov di,[bx]
 push ds
 pop es
 mov [bp+14],es
 mov ds,[bp+0]
 mov si,[bp+2]
 mov cx,[bp+4]
 cld
 rep movsb
 mov byte [es:di],0
 mov bx,[bp+10]
 mov ah,0x80
 xor dx,dx
 push bp
 KCALL 4
 pop bp
 mov es,[bp+14]
 mov word [es:0],0
 mov bx,[bp+10]
 push bp
 KCALL 6
 pop bp
 mov cx,[bp+10]
 mov bx,[bp+8]
 mov ax,bx
 call .bracket
 xor ax,ax
 push bp
 KCALL 411
 pop bp
 call .bracket
 mov [bp+12],ax
 push bp
 KCALL 149
 pop bp
 push bx
 mov ax,0x43
 mov cl,0x50
 mov ch,0x60
 push bp
 KCALL 0
 pop bp
 pop dx
 jc .fail
 mov [bp+10],bx
 mov es,ax
 xor di,di
 mov cx,0x43
 xor al,al
 rep stosb
 mov word [es:0],0
 mov [es:2],dx
 mov word [es:4],0x4000
 mov si,[bp+6]
 mov di,6
 mov cx,32
.name:
 mov al,[cs:si]
 test al,al
 jz .name_end
 mov [es:di],al
 inc si
 inc di
 loop .name
.name_end:
 mov byte [es:di],0
 mov word [es:0x27],1
 mov word [es:0x29],0
 mov ax,[bp+12]
 mov [es:0x41],ax
 mov bx,[bp+10]
 push bp
 KCALL 6
 pop bp
 mov cx,[bp+10]
 mov bx,[bp+8]
 xor ax,ax
 call .bracket
 push bp
 xor bp,bp
 LC 0,127
 pop bp
 clc
 jmp .out
.fail:
 stc
.out:
 lea sp,[bp+16]
 pop es
 pop ds
 pop bp
 pop di
 pop si
 pop dx
 pop cx
 pop bx
 ret
.bracket:
 push ax
 xchg ax,bx
 push bp
 KCALL 399
 pop bp
 xchg ax,bx
 push bp
 KCALL 398
 pop bp
 xchg ax,bx
 pop ax
 ret

