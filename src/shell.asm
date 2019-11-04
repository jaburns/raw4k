BITS 32

LoadLibraryA            equ  0x01364564
Sleep                   equ  0xD9972F53
MessageBoxA             equ  0x36AEF1A0
ChangeDisplaySettingsA  equ  0x96F0EC1C
ShowCursor              equ  0x6D065389
ExitProcess             equ  0x665640AC

%define  kernel32base  ebp-4
%define  user32base    ebp-8
%define  dataPtr       ebp-12
%define  emptyPtr      ebp-16
STACK_LOCALS_SIZE      equ 16

main:
        mov eax, [fs:0x30]            ; get PEB pointer from TEB
        mov eax, [eax+0x0C]           ; get PEB_LDR_DATA pointer from PEB
        mov eax, [eax+0x14]           ; go to first LDR_DATA_TABLE_ENTRY
        mov eax, [eax]                ; go to where ntdll.dll typically is
        mov eax, [eax]                ; go to where kernel32.dll typically is
        mov ebx, [eax+0x10]           ; load base address of the library

     ;  push ebp
     ;  mov ebp, esp
        sub esp, STACK_LOCALS_SIZE    ; save on the stack for local var
        mov dword [kernel32base], ebx       ; store kernel32's base address

        call postData
        db "user32.dll"
        db 0

postData:
        pop eax
        mov [dataPtr], eax
        add eax, 10
        mov [emptyPtr], eax

        mov esi, LoadLibraryA
        push dword [dataPtr]
        call call_import
        mov [user32base], eax

        push 0
        push dword [emptyPtr]
        push dword [dataPtr]
        push 0
        mov ebx, [user32base]
        mov esi, MessageBoxA
        call call_import

        push 0
        mov ebx, [kernel32base]
        mov esi, ExitProcess
        call call_import

call_import:  
        mov edx, [ebx+0x3c]           ; get PE header pointer (w/ RVA translation)
        add edx, ebx
        mov edx, [edx+0x78]           ; get export table pointer RVA (w/ RVA translation)
        add edx, ebx
        push edx                      ; store the export table address for later
        mov ecx, [edx+0x18]           ; ecx = number of named functions
        mov edx, [edx+0x20]           ; edx = address-of-names list (w/ RVA translation)
        add edx, ebx
name_loop:
        push esi                      ; store the desired function name's hash (we will clobber it)
        mov edi, [edx]                ; load function name (w/ RVA translation)
        add edi, ebx
cmp_loop:
        movzx eax, byte [edi]         ; load a byte of the name ...
        inc edi                       ; ... and advance the pointer
        xor esi, eax                  ; apply xor-and-rotate
        rol esi, 7
        or eax, eax                   ; last byte?
        jnz cmp_loop                  ; if not, process another byte
        or esi, esi                   ; result hash match?
        jnz next_name                 ; if not, this is not the correct name

    ; if we arrive here, we have a match!
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
next_name:
        pop esi                       ; restore the name pointer
        add edx, 4                    ; advance to next list item
        dec ecx                       ; decrease counter
        jmp name_loop