BITS 32

%define kernel32base  ebp-16
%define callImport    ebp-20

%define dataPtr       ebp-128
%define user32base    ebp-136

LoadLibraryA  equ  0x01364564
MessageBoxA   equ  0x36AEF1A0
ExitProcess   equ  0x665640AC

start:
        call postData

data_start:
str_user32:     db "user32.dll", 0
str_helloMsg:   db "Hello world!", 0
str_empty:      db 0

postData:
        pop eax
        mov [dataPtr], eax

        mov esi, LoadLibraryA
        mov eax, [dataPtr]
        add eax, (str_user32 - data_start)
        push eax
        call [callImport]
        mov [user32base], eax

        push 0
        mov eax, [dataPtr]
        add eax, (str_empty - data_start)
        push eax
        mov eax, [dataPtr]
        add eax, (str_helloMsg - data_start)
        push eax
        push 0
        mov ebx, [user32base]
        mov esi, MessageBoxA
        call [callImport]

        push 0
        mov eax, [dataPtr]
        add eax, (str_empty - data_start)
        push eax
        mov eax, [dataPtr]
        add eax, (str_user32 - data_start)
        push eax
        push 0
        mov ebx, [user32base]
        mov esi, MessageBoxA
        call [callImport]

        push 0
        mov ebx, [kernel32base]
        mov esi, ExitProcess
        call [callImport]
