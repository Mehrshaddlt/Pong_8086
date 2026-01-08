org 100h

SCREEN_W  equ 80
SCREEN_H  equ 25

BORDER_L  equ 0
BORDER_R  equ 79
BORDER_T  equ 0
BORDER_B  equ 24

PLAY_T    equ 1
PLAY_B    equ 23

PADDLE_H  equ 4
PADDLE_W  equ 1
P1_X      equ 2
P2_X      equ 76

BALL_START_X equ 40
BALL_START_Y equ 12

BALL_TICKS_PER_STEP equ 1

start:
    mov ax, 0003h
    int 10h

    mov ax, 0B800h
    mov es, ax

    call hide_cursor
    call clear_screen
    call draw_border_once

    mov ah, 00h
    int 1Ah
    mov [last_tick], dx
    mov [ball_last_tick], dx

    mov byte [score_l], 0
    mov byte [score_r], 0
    call draw_scores

    mov byte [p1_y], 10
    mov byte [p2_y], 10
    mov byte [p1_oldy], 10
    mov byte [p2_oldy], 10

    call reset_ball
    call draw_paddles
    call draw_ball

main_loop:
    call read_all_input
    call clamp_paddles
    call update_paddles
    call update_ball
    call draw_border_bottom
    jmp main_loop

read_all_input:
.ri_next:
    mov ah, 01h
    int 16h
    jz .ri_done

    mov ah, 00h
    int 16h

    cmp al, 27
    je exit_game

    cmp al, 13
    je .start_ball
    cmp al, 32
    je .start_ball

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

.start_ball:
    mov byte [ball_moving], 1
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
    cmp al, (BORDER_B - PADDLE_H)
    jbe .p1_ok
    mov byte [p1_y], (BORDER_B - PADDLE_H)
.p1_ok:

    mov al, [p2_y]
    cmp al, PLAY_T
    jae .p2_top_ok
    mov byte [p2_y], PLAY_T
.p2_top_ok:
    mov al, [p2_y]
    cmp al, (BORDER_B - PADDLE_H)
    jbe .p2_ok
    mov byte [p2_y], (BORDER_B - PADDLE_H)
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

reset_ball:
    mov byte [ball_moving], 0
    mov byte [ball_x], BALL_START_X
    mov byte [ball_y], BALL_START_Y
    mov byte [ball_oldx], BALL_START_X
    mov byte [ball_oldy], BALL_START_Y
    mov byte [ball_vx], 1
    mov byte [ball_vy], 1
    mov ah, 00h
    int 1Ah
    mov [ball_last_tick], dx
    ret

update_ball:
    cmp byte [ball_moving], 1
    jne .ret

    mov ah, 00h
    int 1Ah
    mov bx, dx
    sub bx, [ball_last_tick]
    cmp bx, BALL_TICKS_PER_STEP
    jb .ret
    mov [ball_last_tick], dx

    call erase_ball_old

    mov al, [ball_x]
    add al, [ball_vx]
    mov [ball_x], al

    mov al, [ball_y]
    add al, [ball_vy]
    mov [ball_y], al

    call check_collisions

    call draw_ball_new

    mov al, [ball_x]
    mov [ball_oldx], al
    mov al, [ball_y]
    mov [ball_oldy], al

.ret:
    ret

check_collisions:
    mov al, [ball_y]
    cmp al, PLAY_T
    jg .chk_bot
    mov byte [ball_vy], 1
    jmp .chk_paddles
.chk_bot:
    cmp al, PLAY_B
    jl .chk_paddles
    mov byte [ball_vy], -1

.chk_paddles:
    mov al, [ball_x]
    cmp al, (P1_X + PADDLE_W)
    jne .chk_p2

    mov ah, [ball_y]
    mov cl, [p1_y]
    cmp ah, cl
    jl .chk_p2
    add cl, PADDLE_H
    cmp ah, cl
    jge .chk_p2
    mov byte [ball_vx], 1

.chk_p2:
    mov al, [ball_x]
    cmp al, (P2_X - 1)
    jne .chk_goals

    mov ah, [ball_y]
    mov cl, [p2_y]
    cmp ah, cl
    jl .chk_goals
    add cl, PADDLE_H
    cmp ah, cl
    jge .chk_goals
    mov byte [ball_vx], -1

.chk_goals:
    mov al, [ball_x]
    cmp al, 1
    jb .right_scores
    cmp al, 78
    ja .left_scores
    ret

.right_scores:
    inc byte [score_r]
    call draw_scores
    call reset_ball
    call draw_ball_new
    ret

.left_scores:
    inc byte [score_l]
    call draw_scores
    call reset_ball
    call draw_ball_new
    ret

erase_ball_old:
    mov al, ' '
    mov ah, 00h
    mov bx, 0
    mov bl, [ball_oldx]
    mov cx, 0
    mov cl, [ball_oldy]
    mov si, 1
    mov di, 1
    call draw_rect
    ret

draw_ball_new:
    mov al, 'O'
    mov ah, 0Eh
    mov bx, 0
    mov bl, [ball_x]
    mov cx, 0
    mov cl, [ball_y]
    mov si, 1
    mov di, 1
    call draw_rect
    ret

draw_ball:
    call draw_ball_new
    mov al, [ball_x]
    mov [ball_oldx], al
    mov al, [ball_y]
    mov [ball_oldy], al
    ret

draw_scores:
    mov al, [score_l]
    call byte_to_digit
    mov ah, 0Fh
    mov bx, 2
    mov cx, 0
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, [score_r]
    call byte_to_digit
    mov ah, 0Fh
    mov bx, 77
    mov cx, 0
    mov si, 1
    mov di, 1
    call draw_rect
    ret

byte_to_digit:
    cmp al, 9
    jbe .ok
    mov al, 9
.ok:
    add al, '0'
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
    mov di, (BORDER_B + 1)
    call draw_rect

    mov bx, BORDER_R
    mov cx, BORDER_T
    mov si, 1
    mov di, (BORDER_B + 1)
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
    inc bx
    mov cx, BORDER_B
    mov si, SCREEN_W
    sub si, 2
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
    shl di, 5
    mov bp, di
    shl di, 2
    add di, bp

    shl bx, 1
    add di, bx

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

p1_y          db 0
p2_y          db 0
p1_oldy       db 0
p2_oldy       db 0

ball_x        db 0
ball_y        db 0
ball_oldx     db 0
ball_oldy     db 0
ball_vx       db 0
ball_vy       db 0
ball_moving   db 0

score_l       db 0
score_r       db 0

last_tick     dw 0
ball_last_tick dw 0
