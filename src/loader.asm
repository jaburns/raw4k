BITS 32

global _mainCRTStartup
section .text

LoadLibraryA  equ  0x01364564
VirtualAlloc  equ  0x57F34BD3
CreateFileA   equ  0x5023E3C4
ReadFile      equ  0xF0B5A43F

;%define fileBuffer    ebp-4

%define kernel32base  ebp-16
%define callImport    ebp-20

_mainCRTStartup:
    ; Stack setup
        mov ebp, esp
        sub esp, 0x100                ; 256 bytes ought to be enough for anyone

    ; Find kernel32
        mov eax, [fs:0x30]            ; get PEB pointer from TEB
        mov eax, [eax+0x0C]           ; get PEB_LDR_DATA pointer from PEB
        mov eax, [eax+0x14]           ; go to first LDR_DATA_TABLE_ENTRY
        mov eax, [eax]                ; go to where ntdll.dll typically is
        mov eax, [eax]                ; go to where kernel32.dll typically is
        mov ebx, [eax+0x10]           ; load base address of the library
        mov dword [kernel32base], ebx ; store kernel32's base address
        mov dword [callImport], call_import

    ; fileBuffer = VirtualAlloc( 0, 0x8000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE );
        push 0x40
        push (0x00001000 | 0x00002000)
        push 0x8000
        push 0
    ;   mov ebx, [kernel32base]
        mov esi, VirtualAlloc
        call call_import

    ; strncpy( [eax], &codeData, codeSize );
        mov edi, eax
        lea esi, byte [codeData]
        mov cx, word [codeSize]
    strCopyLoop:
        mov dx, [esi]
        mov [edi], dx
        inc edi
        inc esi
        dec cx
        jnz strCopyLoop
        jmp eax

call_import:  
        mov edx, [ebx+0x3c]           ; get PE header pointer (w/ RVA translation)
        add edx, ebx
        mov edx, [edx+0x78]           ; get export table pointer RVA (w/ RVA translation)
        add edx, ebx
        push edx                      ; store the export table address for later
        mov ecx, [edx+0x18]           ; ecx = number of named functions
        mov edx, [edx+0x20]           ; edx = address-of-names list (w/ RVA translation)
        add edx, ebx
    .name_loop:
        push esi                      ; store the desired function name's hash (we will clobber it)
        mov edi, [edx]                ; load function name (w/ RVA translation)
        add edi, ebx
    .cmp_loop:
        movzx eax, byte [edi]         ; load a byte of the name ...
        inc edi                       ; ... and advance the pointer
        xor esi, eax                  ; apply xor-and-rotate
        rol esi, 7
        or eax, eax                   ; last byte?
        jnz .cmp_loop                 ; if not, process another byte
        or esi, esi                   ; result hash match?
        jnz .next_name                ; if not, this is not the correct name
        pop esi                       ; restore the name pointer (though we don't use it any longer)
        pop edx                       ; restore the export table address
        sub ecx, [edx+0x18]           ; turn the negative counter ECX into a positive one
        neg ecx
        mov eax, [edx+0x24]           ; get address of ordinal table (w/ RVA translation)
        add eax, ebx
        movzx ecx, word [eax+ecx*2]   ; load ordinal from table
        mov eax, [edx+0x1C]           ; get address of function address table (w/ RVA translation)
        add eax, ebx
        mov eax, [eax+ecx*4]          ; load function address (w/ RVA translation)
        add eax, ebx
        jmp eax                       ; jump to the target function
    .next_name:
        pop esi                       ; restore the name pointer
        add edx, 4                    ; advance to next list item
        dec ecx                       ; decrease counter
        jmp .name_loop

section .data

codeData: incbin "../code.bin"
codeSize: dw     (codeSize - codeData)