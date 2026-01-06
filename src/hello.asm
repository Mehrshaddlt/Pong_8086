org 100h

start:
    mov dx, msg
    mov ah, 09h
    int 21h

    mov ax, 4C00h
    int 21h

msg db "Hello from NASM in DOSBox!$"