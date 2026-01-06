org 100h

PADDLE_H equ 9
PADDLE_W equ 2
P1_X     equ 2
P2_X     equ 76

start:
    mov ax, 0B800h
    mov es, ax

    call hide_cursor
    call clear_screen

    mov byte [p1_y], 8
    mov byte [p2_y], 8

    mov ah, 00h
    int 1Ah
    mov [last_tick], dx

main_loop:
    call wait_tick
    call read_all_input
    call clamp_paddles

    call clear_screen

    mov al, 219
    mov ah, 1Fh

    mov bx, P1_X
    xor cx, cx
    mov cl, [p1_y]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect

    mov bx, P2_X
    xor cx, cx
    mov cl, [p2_y]
    mov si, PADDLE_W
    mov di, PADDLE_H
    call draw_rect

    jmp main_loop

wait_tick:
    push ax
    push cx
    push dx
.loop:
    mov ah, 00h
    int 1Ah
    mov cx, [last_tick]
    cmp dx, cx
    je .loop
    mov [last_tick], dx
    pop dx
    pop cx
    pop ax
    ret

read_all_input:
.next:
    mov ah, 01h
    int 16h
    jz .done

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
    jne .next

    cmp ah, 48h
    je .p2_up
    cmp ah, 50h
    je .p2_down
    jmp .next

.p1_up:
    mov al, [p1_y]
    cmp al, 0
    je .next
    dec byte [p1_y]
    jmp .next

.p1_down:
    inc byte [p1_y]
    jmp .next

.p2_up:
    mov al, [p2_y]
    cmp al, 0
    je .next
    dec byte [p2_y]
    jmp .next

.p2_down:
    inc byte [p2_y]
    jmp .next

.done:
    ret

clamp_paddles:
    mov al, [p1_y]
    cmp al, 25 - PADDLE_H
    jbe .p1_ok
    mov byte [p1_y], 25 - PADDLE_H
.p1_ok:
    mov al, [p2_y]
    cmp al, 25 - PADDLE_H
    jbe .p2_ok
    mov byte [p2_y], 25 - PADDLE_H
.p2_ok:
    ret

exit_game:
    call show_cursor
    call clear_screen
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

.row:
    push dx
    mov cx, bp
.col:
    mov [es:di], ax
    add di, 2
    loop .col
    pop dx

    add di, 160
    mov bx, bp
    shl bx, 1
    sub di, bx

    dec dx
    jnz .row

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

p1_y db 8
p2_y db 8
last_tick dw 0
