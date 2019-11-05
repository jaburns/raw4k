;======================================================================================================
;  Ultra-small EXE layout and hash-based DLL function finder forked from KeyJ's console clipboard app
;    https://keyj.emphy.de/win32-pe/
;
BITS 32

LoadLibraryA  equ  0x01364564
VirtualAlloc  equ  0x57F34BD3
CreateFileA   equ  0x5023E3C4
ReadFile      equ  0xF0B5A43F

%define kernel32base  ebp-16
%define callImport    ebp-20

BASE        equ  0x00400000
FRAME_SIZE  equ  0x100

%define RVA(obj) (obj - BASE)

org BASE

mz_hdr: dw "MZ"                   ; DOS magic
        dw "jb"                   ; filler to align the PE header

pe_hdr: dw "PE",0                 ; PE magic + 2 padding bytes
        dw 0x014c                 ; i386 architecture
        dw 0                      ; no sections

main1:  ; 12 unused bytes
        mov eax, [eax+0x14]       ; go to first LDR_DATA_TABLE_ENTRY
        mov eax, [eax]            ; go to where ntdll.dll typically is
        mov eax, [eax]            ; go to where kernel32.dll typically is
        mov ebx, [eax+0x10]       ; load base address of the library
        jmp main2

        dw 8                      ; optional header size
        dw 0x0102                 ; characteristics: 32-bit, executable
opt_hdr:
        dw 0x010b                 ; optional header magic

main0:  ; 14 unused bytes
        mov eax, [fs:0x30]        ; get PEB pointer from TEB
        mov eax, [eax+0x0C]       ; get PEB_LDR_DATA pointer from PEB
        mov ebp, esp              ; setup stack base pointer
        jmp main1
        db 0

        dd RVA(main0)             ; entry point address

main2:  ; 8 unused bytes
        sub esp, FRAME_SIZE       ; set aside some space for local vars
        jmp main3

        dd BASE                   ; image base
        dd 4                      ; section alignment (collapsed with the PE header offset in the DOS header)
        dd 4                      ; file alignment

        ; 8 unused bytes
main5:  push (0x00001000 | 0x00002000) ; 3rd arg to VirtualAlloc: MEM_COMMIT | MEM_RESERVE
        jmp main6
        db 0

        dw 4,0                    ; subsystem version

main3:  ; 4 unused bytes
        push 0x40                 ; 4th arg to VirtualAlloc: PAGE_EXECUTE_READWRITE
        jmp main4

        dd RVA(the_end)           ; size of image
        dd RVA(opt_hdr)           ; size of headers (must be small enough so that entry point inside header is accepted)

        ; 4 unused bytes
main4:  jmp main5                 ; jumping straight to main5 from main3 crashes for some reason, but this works!
        dw 0

        dw 2                      ; subsystem = 2:GUI  3:Console
        dw 0                      ; DLL characteristics
        dd 0x00100000             ; maximum stack size
        dd 0x00001000             ; initial stack size
        dd 0x00100000             ; maximum heap size
        dd 0x00001000             ; initial heap size

        ; 4 unused bytes
        dd 0

        dd 0                          ; number of data directory entries (= none!)
main6:
        mov dword [kernel32base], ebx ; store kernel32's base address
        mov dword [callImport], call_import

    ; fileBuffer = VirtualAlloc( 0, 0x8000, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE );
        push 0x8000               ; 2nd arg to VirtualAlloc, size: 0x8000
        push 0                    ; 1st arg to VirtualAlloc, address: NULL (give us a fresh address)
        mov esi, VirtualAlloc
        call call_import

%ifdef DEBUG
        mov edi, eax
        lea esi, byte [payloadData]
        mov cx, (the_end - payloadData)
    strCopyLoop:
        mov dx, [esi]
        mov [edi], dx
        inc edi
        inc esi
        dec cx
        jnz strCopyLoop
        jmp eax
%else
        push eax
        mov edi, eax
        mov eax, payloadData
        movzx ebx, byte [eax]
        lea edx, dword [eax+1]
        xor esi, esi
        mov ecx, esi
    dictLoop:
        movzx eax, byte [edx]
        mov dword [esp+ecx*4-2048], edx
        inc edx
        add edx, eax
        inc ecx
        cmp ecx, ebx
        jl dictLoop
    unpackLoop:
        mov al, byte [edx]
        inc edx
        cmp al, 255 
        jne copyByte
        movzx eax, byte [edx]
        inc edx
        mov ecx, dword [esp+eax*4-2048]
        movzx ebx, byte [ecx]
        inc ecx
        test ebx, ebx
        je endUnpackLoop
        add esi, ebx
    copyFromDictLoop:
        mov al, byte [ecx]
        mov byte [edi], al
        inc edi
        inc ecx
        dec ebx
        test ebx, ebx
        jg copyFromDictLoop
        jmp endUnpackLoop
    copyByte:
        mov byte [edi], al
        inc edi
        inc esi
    endUnpackLoop:
        cmp edx, the_end
        jb unpackLoop
        ret ; pop eax, jmp eax
%endif

call_import:  
        mov edx, [ebx+0x3c]           ; get PE header pointer (w/ RVA translation)
        add edx, ebx
        mov edx, [edx+0x78]           ; get export table pointer RVA (w/ RVA translation)
        add edx, ebx
        push edx                      ; store the export table address for later
        mov ecx, [edx+0x18]           ; ecx = number of named functions
        mov edx, [edx+0x20]           ; edx = address-of-names list (w/ RVA translation)
        add edx, ebx
    .nameLoop:
        push esi                      ; store the desired function name's hash (we will clobber it)
        mov edi, [edx]                ; load function name (w/ RVA translation)
        add edi, ebx
    .cmpLoop:
        movzx eax, byte [edi]         ; load a byte of the name ...
        inc edi                       ; ... and advance the pointer
        xor esi, eax                  ; apply xor-and-rotate
        rol esi, 7
        or eax, eax                   ; last byte?
        jnz .cmpLoop                  ; if not, process another byte
        or esi, esi                   ; result hash match?
        jnz .nextName                 ; if not, this is not the correct name
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
    .nextName:
        pop esi                       ; restore the name pointer
        add edx, 4                    ; advance to next list item
        dec ecx                       ; decrease counter
        jmp .nameLoop

payloadData:
    %ifdef DEBUG
        incbin "../bin/payload.bin"
    %else
        incbin "../bin/payload.z"
    %endif

align 4, db 0
the_end: