org 100h

SCREEN_W  equ 80
SCREEN_H  equ 25

BORDER_L  equ 0
BORDER_R  equ 79
BORDER_T  equ 0
BORDER_B  equ 12

PLAY_T    equ 1
PLAY_B    equ 23

PADDLE_H  equ 7
PADDLE_W  equ 2
P1_X      equ 2
P2_X      equ 76

start:
    mov ax, 0003h
    int 10h

    mov ax, 0B800h
    mov es, ax

    call hide_cursor
    call clear_screen
    call draw_border_once

    mov byte [p1_y], 9
    mov byte [p2_y], 9
    mov byte [p1_oldy], 9
    mov byte [p2_oldy], 9

    call draw_paddles

main_loop:
    call wait_tick
    call read_all_input
    call clamp_paddles
    call update_paddles
    call draw_border_bottom
    jmp main_loop

wait_tick:
    push ax
    push cx
    push dx
    mov ah, 00h
    int 1Ah
    mov cx, dx
.wt_loop:
    mov ah, 00h
    int 1Ah
    cmp dx, cx
    je .wt_loop
    pop dx
    pop cx
    pop ax
    ret

read_all_input:
.ri_next:
    mov ah, 01h
    int 16h
    jz .ri_done

    mov ah, 00h
    int 16h

    cmp al, 27
    je exit_game

    cmp al, 'w'
    je .p1_up
    cmp al, 'W'
    je .p1_up
    cmp al, 's'
    je .p1_down
    cmp al, 'S'
    je .p1_down

    cmp al, 0
    jne .ri_next
    cmp ah, 48h
    je .p2_up
    cmp ah, 50h
    je .p2_down
    jmp .ri_next

.p1_up:
    dec byte [p1_y]
    jmp .ri_next
.p1_down:
    inc byte [p1_y]
    jmp .ri_next
.p2_up:
    dec byte [p2_y]
    jmp .ri_next
.p2_down:
    inc byte [p2_y]
    jmp .ri_next

.ri_done:
    ret

clamp_paddles: 
    mov al, [p1_y]
    cmp al, PLAY_T
    jae .p1_top_ok
    mov byte [p1_y], PLAY_T
.p1_top_ok: 
    mov al, [p1_y]
    cmp al, (PLAY_B - PADDLE_H + 1 - 9)
    jbe .p1_ok
    mov byte [p1_y], (PLAY_B - PADDLE_H + 1 - 9)
.p1_ok:

    mov al, [p2_y]
    cmp al, PLAY_T
    jae .p2_top_ok
    mov byte [p2_y], PLAY_T
.p2_top_ok:
    mov al, [p2_y]
    cmp al, (PLAY_B - PADDLE_H + 1 - 9)
    jbe .p2_ok
    mov byte [p2_y], (PLAY_B - PADDLE_H + 1 - 9)
.p2_ok: 
    ret

update_paddles:
    mov al, [p1_y]
    cmp al, [p1_oldy]
    je .chk2
    call erase_p1_old
    call draw_p1_new
    mov al, [p1_y]
    mov [p1_oldy], al

.chk2:
    mov al, [p2_y]
    cmp al, [p2_oldy]
    je .done
    call erase_p2_old
    call draw_p2_new
    mov al, [p2_y]
    mov [p2_oldy], al

.done:
    ret

erase_p1_old: 
    mov al, ' '
    mov ah, 00h
    mov bx, P1_X
    xor cx, cx
    mov cl, [p1_oldy]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect
    ret

erase_p2_old: 
    mov al, ' '
    mov ah, 00h
    mov bx, P2_X
    xor cx, cx
    mov cl, [p2_oldy]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect
    ret

draw_p1_new: 
    mov al, 219
    mov ah, 0Fh
    mov bx, P1_X
    xor cx, cx
    mov cl, [p1_y]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect
    ret

draw_p2_new:
    mov al, 219
    mov ah, 0Fh
    mov bx, P2_X
    xor cx, cx
    mov cl, [p2_y]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect
    ret

draw_paddles:
    call draw_p1_new
    call draw_p2_new
    ret

draw_border_once:
    mov ah, 0Bh

    mov al, 196
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, SCREEN_W
    mov di, 1
    call draw_rect

    mov al, 179
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, 1
    mov di, SCREEN_H
    call draw_rect

    mov bx, BORDER_R
    mov cx, BORDER_T
    mov si, 1
    mov di, SCREEN_H
    call draw_rect

    mov al, 218
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 191
    mov bx, BORDER_R
    mov cx, BORDER_T
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 192
    mov bx, BORDER_L
    mov cx, BORDER_B
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 217
    mov bx, BORDER_R
    mov cx, BORDER_B
    mov si, 1
    mov di, 1
    call draw_rect

    ret

draw_border_bottom: 
    mov ah, 0Bh
    mov al, 196
    mov bx, BORDER_L
    mov cx, BORDER_B
    mov si, SCREEN_W
    mov di, 1
    call draw_rect
    ret

exit_game:
    call show_cursor
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

hide_cursor:
    mov ah, 01h
    mov cx, 2607h
    int 10h
    ret

show_cursor:
    mov ah, 01h
    mov cx, 0607h
    int 10h
    ret

clear_screen:
    push ax
    push cx
    push di
    mov ax, 0720h
    xor di, di
    mov cx, 2000
    rep stosw
    pop di
    pop cx
    pop ax
    ret

draw_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov dx, di
    mov di, cx

    shl di, 7
    mov bp, cx
    shl bp, 5
    add di, bp
    add di, bx
    shl di, 1

    mov bp, si

.dr_row:
    push dx
    mov cx, bp
.dr_col:
    mov [es:di], ax
    add di, 2
    loop .dr_col
    pop dx

    add di, 160
    mov bx, bp
    shl bx, 1
    sub di, bx

    dec dx
    jnz .dr_row

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

p1_y     db 0
p2_y     db 0
p1_oldy  db 0
p2_oldy  db 0
