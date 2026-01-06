org 100h

start:
    mov ax, 0B800h
    mov es, ax

    call hide_cursor
    call clear_screen

main_loop:
    call clear_screen

    mov al, 219
    mov ah, 1Fh

    mov bx, 2
    mov cx, 8
    mov si, 2
    mov di, 9
    call draw_rect

    mov bx, 76
    mov cx, 8
    mov si, 2
    mov di, 9
    call draw_rect

    call poll_esc
    cmp al, 1
    je exit_game

    call delay
    jmp main_loop

exit_game:
    call show_cursor
    call clear_screen
    mov ax, 4C00h
    int 21h

poll_esc:
    mov ah, 01h
    int 16h
    jz .no_key

    mov ah, 00h
    int 16h
    cmp al, 27
    jne .no_key

    mov al, 1
    ret

.no_key:
    xor al, al
    ret

delay:
    push cx
    push dx
    mov cx, 40
.outer:
    mov dx, 30000
.inner:
    dec dx
    jnz .inner
    loop .outer
    pop dx
    pop cx
    ret

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
