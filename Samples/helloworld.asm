BITS 32

section .text
    db 'MZ'
    dw 0
    dd 'PE'
    dw 0x014C
    dw 1
    dd 0
    dd 0
    dd 0
    dw 0xE0
    dw 0x010F
    dd 0x10B
    dw 0
    dd 0x1000
    dd 0x1000
    dd 0
    dd 0x1000
    dd 0x1000
    dd 0x2000
    dd 0x400000
    dd 0x1000
    dd 0x1000
    dw 4
    dw 0
    dw 4
    dd 0
    dd 0x1000
    dd 0
    dw 2
    dw 0
    dd 0x10000
    dd 0x10000
    dd 0x10000
    dd 0
    dd 0
    dd 16
    db '.text',0,0,0
    dd 0x1000
    dd 0x1000
    dd 0x200
    dd 0x1000
    dd 0
    dd 0
    dw 0
    dw 0
    dd 0x60000020

section .idata
    dd 0, 0, 0, 0, 0
    dd kernel32_dll
    dd import_table

kernel32_dll db 'kernel32.dll',0

import_table:
    dd 0, 0, 0, 0
    dd getstdhandle_name
    dd getstdhandle_ptr
    dd 0, 0, 0, 0
    dd writeconsole_name
    dd writeconsole_ptr
    dd 0, 0, 0, 0
    dd exitprocess_name
    dd exitprocess_ptr
    dd 0, 0, 0, 0, 0

getstdhandle_name db 'GetStdHandle',0
writeconsole_name db 'WriteConsoleA',0
exitprocess_name db 'ExitProcess',0

getstdhandle_ptr dd 0
writeconsole_ptr dd 0
exitprocess_ptr dd 0

section .text
global _start
_start:
    push -11
    call [getstdhandle_ptr]
    mov ebx, eax
    push 0
    push 0
    push msg_len
    push msg
    push ebx
    call [writeconsole_ptr]
    push 0
    call [exitprocess_ptr]

section .data
msg db 'Hello, world!', 0Dh, 0Ah
msg_len equ $ - msg
