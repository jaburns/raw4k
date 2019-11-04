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

BASE       equ  0x00400000
ALIGNMENT  equ  4
SECTALIGN  equ  4

%define RVA(obj) (obj - BASE)

org BASE

mz_hdr: dw "MZ"                       ; DOS magic
        dw "jb"                       ; filler to align the PE header
pe_hdr: dw "PE",0                     ; PE magic + 2 padding bytes
        dw 0x014c                     ; i386 architecture
dw_zero:
        dw 0                          ; no sections
        dd 0                          ; [UNUSED-12] timestamp
        dd 0                          ; [UNUSED] symbol table pointer
        dd 0                          ; [UNUSED] symbol count
        dw 8                          ; optional header size
        dw 0x0102                     ; characteristics: 32-bit, executable
opt_hdr:
        dw 0x010b                     ; optional header magic
        db 13,37                      ; [UNUSED-14] linker version
        dd 0                          ; [UNUSED] code size
        dd 0                          ; [UNUSED] size of initialized data
        dd 0                          ; [UNUSED] size of uninitialized data
        dd RVA(main)                  ; entry point address
        dd 0                          ; [UNUSED-8] base of code
        dd 0                          ; [UNUSED] base of data
        dd BASE                       ; image base
        dd SECTALIGN                  ; section alignment (collapsed with the PE header offset in the DOS header)
        dd ALIGNMENT                  ; file alignment
        dw 4,0                        ; [UNUSED-8] OS version
        dw 0,0                        ; [UNUSED] image version
        dw 4,0                        ; subsystem version
        dd 0                          ; [UNUSED-4] Win32 version
        dd RVA(the_end)               ; size of image
        dd RVA(opt_hdr)               ; size of headers (must be small enough so that entry point inside header is accepted)
        dd 0                          ; [UNUSED-4] checksum
        dw 2                          ; subsystem = 2:GUI  3:Console
        dw 0                          ; [UNUSED-2] DLL characteristics
        dd 0x00100000                 ; maximum stack size
        dd 0x00001000                 ; initial stack size
        dd 0x00100000                 ; maximum heap size
        dd 0x00001000                 ; initial heap size
        dd 10000                      ; [UNUSED-4] loader flags
        dd 0                          ; number of data directory entries (= none!)
main:
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

    ; strncpy( [eax], &payloadData, payloadSize );
        mov edi, eax
        lea esi, byte [payloadData]
        mov cx, word [payloadSize]
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

payloadData: incbin "../bin/payload.bin"
payloadSize: dw     (payloadSize - payloadData)

align ALIGNMENT, db 0
the_end: