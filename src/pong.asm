org 100h

; Constants
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

MID_X     equ 39

; Adjustment for the FPS
BALL_DELAY_MAX equ 16000 

BALL_START_X equ 40
BALL_START_Y equ 12

WIN_SCORE equ 10

; Score display coordinates
SCORE_L_X equ (MID_X / 2)
SCORE_R_X equ (MID_X + 1 + ((SCREEN_W - 1 - MID_X) / 2))
SCORE_Y   equ 0

; Entry Point & Menu
start:
    ; Set Video Mode 03h (80x25 text)
    mov ax, 0003h
    int 10h

    ; Setup Segment Register for Video Memory
    mov ax, 0B800h
    mov es, ax

    call hide_cursor

show_menu:
    call clear_screen
    
    ; Draw Title
    mov bx, 35          
    mov cx, 8           
    mov si, title_txt
    call draw_text

    ; Draw Option 1
    mov bx, 30
    mov cx, 12
    mov si, opt1_txt
    call draw_text

    ; Draw Option 2
    mov bx, 30
    mov cx, 14
    mov si, opt2_txt
    call draw_text

    ; Draw Instructions
    mov bx, 28
    mov cx, 20
    mov si, instr_txt
    call draw_text

.menu_loop:
    mov ah, 00h
    int 16h             ; Wait for key press

    cmp al, '1'
    je .start_pvp

    cmp al, '2'
    je .start_ai

    cmp al, 27          ; ESC to quit
    je exit_game
    
    jmp .menu_loop

.start_pvp:
    mov byte [ai_enabled], 0
    jmp init_game

.start_ai:
    mov byte [ai_enabled], 1
    jmp init_game

; Game Initialization
init_game:
    call clear_screen
    call draw_border_once
    call draw_midline

    ; Seed random numbers logic is handled inside reset_ball later
    ; But we init timers here just in case
    mov ah, 00h
    int 1Ah
    mov [last_tick], dx
    mov [ball_last_tick], dx

    ; Reset Scores
    mov byte [score_l], 0
    mov byte [score_r], 0
    mov byte [game_over], 0
    call draw_scores

    ; Reset Paddles
    mov byte [p1_y], 10
    mov byte [p2_y], 10
    mov byte [p1_oldy], 10
    mov byte [p2_oldy], 10

    call reset_ball

    call draw_paddles
    call draw_ball

; Main Game Loop
main_loop:
    call read_all_input
    call clamp_paddles
    call update_paddles
    call update_ball
    call draw_border_bottom
    jmp main_loop

; Input Handling & AI
read_all_input:
.ri_next:
    ; Check if key is available buffer
    mov ah, 01h
    int 16h
    jz .check_ai        ; If no input, jump to AI check

    ; Consume key
    mov ah, 00h
    int 16h

    cmp al, 27          ; ESC
    je exit_game

    cmp al, 13          ; ENTER
    je .enter_key
    cmp al, 32          ; SPACE
    je .start_ball

    ; P1 Controls
    cmp al, 'w'
    je .p1_up
    cmp al, 'W'
    je .p1_up
    cmp al, 's'
    je .p1_down
    cmp al, 'S'
    je .p1_down

    ; P2 Controls (Only if AI is OFF)
    cmp byte [ai_enabled], 1
    je .ri_next         ; Skip arrow keys if AI is on

    cmp al, 0
    jne .ri_next        ; Extended keys have AL=0
    cmp ah, 48h         ; Up Arrow
    je .p2_up
    cmp ah, 50h         ; Down Arrow
    je .p2_down
    jmp .ri_next

.enter_key:
    ; If game ended, ENTER returns to menu
    cmp byte [game_over], 1
    jne .start_ball
    jmp show_menu       ; Go back to menu instead of just resetting
    
.start_ball:
    cmp byte [game_over], 1
    je .ri_next
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

.check_ai:
    cmp byte [ai_enabled], 1
    jne .ri_done                ; If not AI, we are done
    call run_ai_logic           ; Run the bot
    
.ri_done:
    ret

; AI Logic
run_ai_logic:
    ; Direction
    cmp byte [ball_vx], 1
    jne .ai_ret

    ; Visibility
    cmp byte [ball_x], 30
    jl .ai_ret

    ; Mistake
    push ax
    push dx
    mov ah, 00h
    int 1Ah         
    test dl, 00000011b  
    pop dx
    pop ax
    jz .ai_ret      

    ; Targeting
    mov al, [p2_y]
    add al, 2       
    cmp al, [ball_y]
    
    jg .go_up       
    jl .go_down     
    jmp .ai_ret     

.go_up:
    dec byte [p2_y]
    jmp .ai_ret
.go_down:
    inc byte [p2_y]
.ai_ret:
    ret

; Game Logic
clamp_paddles:
    ; Clamp P1
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
    ; Clamp P2
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
    ; Draw P1 only if moved
    mov al, [p1_y]
    cmp al, [p1_oldy]
    je .chk2
    call erase_p1_old
    call draw_p1_new
    mov al, [p1_y]
    mov [p1_oldy], al

.chk2:
    ; Draw P2 only if moved
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

    ; Randomize Direction
    mov ah, 00h
    int 1Ah        
    
    ; Random Horizontal
    test dl, 1      
    jz .vx_neg      
    mov byte [ball_vx], 1
    jmp .check_vy
.vx_neg:
    mov byte [ball_vx], -1

.check_vy:
    ; Random Vertical
    test dl, 2      
    jz .vy_neg     
    mov byte [ball_vy], 1
    jmp .finish_reset

.vy_neg:
    mov byte [ball_vy], -1

.finish_reset:
    mov ah, 00h
    int 1Ah
    mov [ball_last_tick], dx
    ret

update_ball:
    cmp byte [game_over], 1
    je .ret

    cmp byte [ball_moving], 1
    jne .ret

    ; Smooth Timer Delay
    dec word [ball_delay_counter]
    jnz .ret                    ; Wait until counter is 0
    
    ; Reset counter
    mov word [ball_delay_counter], BALL_DELAY_MAX
    call erase_ball_old

    ; Update Positions
    mov al, [ball_x]
    add al, [ball_vx]
    mov [ball_x], al

    mov al, [ball_y]
    add al, [ball_vy]
    mov [ball_y], al

    call check_collisions

    call draw_ball_new

    ; Save old positions
    mov al, [ball_x]
    mov [ball_oldx], al
    mov al, [ball_y]
    mov [ball_oldy], al

.ret:
    ret

check_collisions:
    ; Top/Bottom Walls
    mov al, [ball_y]
    cmp al, PLAY_T
    jg .chk_bot
    mov byte [ball_vy], 1
    call sfx_wall       
    jmp .chk_p1
.chk_bot:
    cmp al, PLAY_B
    jl .chk_p1
    mov byte [ball_vy], -1
    call sfx_wall      

    ; Paddle 1 (Left) Range Check
.chk_p1:
    cmp byte [ball_vx], -1      
    jne .chk_p2

    ; Is ball x between P1 front and back?
    mov al, [ball_x]
    cmp al, (P1_X + PADDLE_W)   
    jg .chk_p2                  
    cmp al, P1_X                
    jl .chk_p2                  

    ; Is ball y within paddle height?
    mov ah, [ball_y]
    mov cl, [p1_y]
    cmp ah, cl
    jl .chk_p2
    add cl, PADDLE_H
    cmp ah, cl
    jge .chk_p2

    ; Hit P1
    mov byte [ball_vx], 1       
    call sfx_paddle
    ret                         

    ; Paddle 2 (Right) Range Check
.chk_p2:
    cmp byte [ball_vx], 1       
    jne .chk_goals

    ; Is ball x between P2 front and back?
    mov al, [ball_x]
    cmp al, (P2_X - 1)          
    jl .chk_goals               
    cmp al, P2_X                
    jg .chk_goals               

    ; Is ball y within paddle height?
    mov ah, [ball_y]
    mov cl, [p2_y]
    cmp ah, cl
    jl .chk_goals
    add cl, PADDLE_H
    cmp ah, cl
    jge .chk_goals

    ; Hit P2
    mov byte [ball_vx], -1      
    call sfx_paddle
    ret                         

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
    call sfx_score       
    call check_win_state
    call reset_ball
    call draw_ball_new
    ret

.left_scores:
    inc byte [score_l]
    call draw_scores
    call sfx_score      
    call check_win_state
    call reset_ball
    call draw_ball_new
    ret

check_win_state:
    ; Left wins?
    mov al, [score_l]
    cmp al, WIN_SCORE
    jne .chk_right
    mov byte [game_over], 1
    mov byte [winner_side], 0      
    call show_winner_screen
    ret
.chk_right:
    ; Right wins?
    mov al, [score_r]
    cmp al, WIN_SCORE
    jne .done
    mov byte [game_over], 1
    mov byte [winner_side], 1      
    call show_winner_screen
.done:
    ret

show_winner_screen:
    mov byte [ball_moving], 0

    cmp byte [winner_side], 0
    jne .right_wins

.left_wins:
    mov bx, SCORE_L_X
    mov cx, SCORE_Y
    mov si, winner_txt
    call draw_text

    mov bx, SCORE_R_X
    mov cx, SCORE_Y
    mov si, loser_txt
    call draw_text
    ret

.right_wins:
    mov bx, SCORE_L_X
    mov cx, SCORE_Y
    mov si, loser_txt
    call draw_text

    mov bx, SCORE_R_X
    mov cx, SCORE_Y
    mov si, winner_txt
    call draw_text
    ret

reset_game:
    mov byte [score_l], 0
    mov byte [score_r], 0
    mov byte [game_over], 0
    call draw_scores
    call reset_ball
    call draw_ball_new
    ret

; Drawing Functions
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
    mov al, 254       ; Square block char
    mov ah, 0Fh
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
    ; Clear areas
    mov bx, SCORE_L_X
    mov cx, SCORE_Y
    mov si, blank6_txt
    call draw_text
    mov bx, SCORE_R_X
    mov cx, SCORE_Y
    mov si, blank6_txt
    call draw_text

    ; Draw Left
    mov al, [score_l]
    call byte_to_digit
    mov ah, 0Fh
    mov bx, SCORE_L_X
    mov cx, SCORE_Y
    mov si, 1
    mov di, 1
    call draw_rect

    ; Draw Right
    mov al, [score_r]
    call byte_to_digit
    mov ah, 0Fh
    mov bx, SCORE_R_X
    mov cx, SCORE_Y
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

draw_text:
    ; BX=x, CX=y, SI=string
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    ; Calc offset: (y*160) + (x*2)
    mov di, cx
    shl di, 5
    mov bp, di
    shl di, 2
    add di, bp
    shl bx, 1
    add di, bx

.dt_loop:
    lodsb
    cmp al, 0
    je .dt_done
    mov ah, 0Fh
    mov [es:di], ax
    add di, 2
    jmp .dt_loop

.dt_done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_midline:
    mov al, 179
    mov ah, 08h
    mov bx, MID_X
    mov cx, PLAY_T
    mov si, 1
    mov di, (PLAY_B - PLAY_T + 1)
.dm_loop:
    push cx
    test cl, 1
    jz .skip
    mov si, 1
    mov di, 1
    call draw_rect
.skip:
    pop cx
    inc cx
    dec di
    jnz .dm_loop
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
    ; Top
    mov ah, 0Bh
    mov al, 196
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, SCREEN_W
    mov di, 1
    call draw_rect

    ; Left Side
    mov al, 179
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, 1
    mov di, (BORDER_B + 1)
    call draw_rect

    ; Right Side
    mov bx, BORDER_R
    mov cx, BORDER_T
    mov si, 1
    mov di, (BORDER_B + 1)
    call draw_rect

    ; Corners
    mov al, 218 ; TL
    mov bx, BORDER_L
    mov cx, BORDER_T
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 191 ; TR
    mov bx, BORDER_R
    mov cx, BORDER_T
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 192 ; BL
    mov bx, BORDER_L
    mov cx, BORDER_B
    mov si, 1
    mov di, 1
    call draw_rect

    mov al, 217 ; BR
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
    ; SI=w, DI=h, BX=x, CX=y, AL=char, AH=attr
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

; Sound Effects
play_tone:
    push ax
    push bx
    push cx
    push dx

    ; Setup PIT
    mov al, 0B6h
    out 43h, al
    
    ; Frequency
    mov dx, 42h
    mov bx, ax
    mov al, bl
    out dx, al
    mov al, bh
    out dx, al

    ; Speaker ON
    in  al, 61h
    mov ah, al
    or  al, 03h
    out 61h, al

.delay:
    push cx         ; Extra cycle burn for stability
    pop cx  
    loop .delay

    ; Speaker OFF
    mov al, ah
    out 61h, al

    pop dx
    pop cx
    pop bx
    pop ax
    ret

sfx_gap:
    push cx
    mov cx, 5000       
.g:
    nop
    loop .g
    pop cx
    ret

sfx_wall:
    mov ax, 2000        
    mov ax, 900         
    mov cx, 15000       
    call play_tone
    ret

sfx_paddle:
    mov ax, 600          
    mov cx, 8000
    call play_tone
    call sfx_gap
    mov ax, 1000         
    mov cx, 8000
    call play_tone
    ret

sfx_score:
    mov ax, 1500        
    mov cx, 15000
    call play_tone
    call sfx_gap
    mov ax, 1000        
    mov cx, 15000
    call play_tone
    call sfx_gap
    mov ax, 500         
    mov cx, 20000
    call play_tone
    ret

; Data Section
winner_txt db 'WINNER',0
loser_txt  db 'LOSER ',0
blank6_txt db '      ',0

; Menu Strings
title_txt  db 'PONG 8086',0
opt1_txt   db '1. Human vs Human',0
opt2_txt   db '2. Human vs Bot',0
instr_txt  db 'Press 1 or 2 to start',0

p1_y           db 0
p2_y           db 0
p1_oldy        db 0
p2_oldy        db 0

ball_x         db 0
ball_y         db 0
ball_oldx      db 0
ball_oldy      db 0
ball_vx        db 0
ball_vy        db 0
ball_moving    db 0

score_l        db 0
score_r        db 0

game_over      db 0
winner_side    db 0

ai_enabled     db 0    ; 0 = PVP, 1 = AI

ball_delay_counter dw BALL_DELAY_MAX
last_tick      dw 0
ball_last_tick dw 0
