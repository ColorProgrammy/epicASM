bits 32

section .text
global _start

extern _MessageBoxA@16
extern _ExitProcess@4

_start:
    push 0               ; MB_OK
    push caption
    push message
    push 0               ; hWnd
    call _MessageBoxA@16
    
    push 0
    call _ExitProcess@4

section .data
message  db 'Hello World!',0
caption db 'Info',0