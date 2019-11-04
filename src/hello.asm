BITS 32

global _mainCRTStartup
extern _ExitProcess@4
extern _MessageBoxA@16
extern _CreateFileA@28
extern _ReadFile@20
extern _WriteFile@20
extern _CloseHandle@4
extern _VirtualAlloc@16
section .text

_mainCRTStartup:
    ; Stack setup
        push ebp
        mov ebp, esp
        %define fileInHandle  ebp-4
        %define fileOutHandle ebp-8
        %define fileSize      ebp-12
        %define fileBuffer    ebp
        sub esp, 12

    ; CreateFile( str_fileIn, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0 );
        push 0
        push 0x80
        push 3
        push 0
        push 1
        push 0x80000000
        push str_fileIn
        call _CreateFileA@28
        mov [fileInHandle], eax

    ; CreateFile( str_fileOut, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0 );
        push 0
        push 0x80
        push 2
        push 0
        push 0
        push 0x40000000
        push str_fileOut
        call _CreateFileA@28
        mov [fileOutHandle], eax

    ; fileBuffer = VirtualAlloc( 0, 0x8000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE );
        push 0x40
        push (0x00001000 | 0x00002000)
        push 0x8000
        push 0
        call _VirtualAlloc@16
        mov [fileBuffer], eax

    ; ReadFile( fileInHandle, fileBuffer, 0x2000, &fileSize, 0 );
        push 0
        lea eax, [fileSize]
        push eax
        push 0x2000
        push dword [fileBuffer]
        push dword [fileInHandle]
        call _ReadFile@20
        jmp [fileBuffer]

    ; WriteFile( fileOutHandle, &fileBuffer, fileSize, &fileSize, 0 );
        push 0
        lea eax, [fileSize]
        push eax
        push dword [fileSize]
        push dword [fileBuffer]
        push dword [fileOutHandle]
        call _WriteFile@20

    ; MessageBoxA( NULL, str_message, "", 0 );
        push 0
        push str_zempty
        push str_message
        push 0
        call _MessageBoxA@16

    ; CloseHandle( fileInHandle );
        push dword [fileInHandle]
        call _CloseHandle@4

    ; CloseHandle( fileOutHandle );
        push dword [fileOutHandle]
        call _CloseHandle@4

    ; ExitProcess( 0 );
        push 0
        call _ExitProcess@4

section .data

str_fileIn   db  "shell", 0
str_fileOut  db  "aaaaa.exe", 0

str_message  db  "Hello world", 0
str_zempty   db  0