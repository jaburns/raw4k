;==================================================================================================
;  Ultra-small EXE layout forked from KeyJ's console clipboard app
;    https://keyj.emphy.de/win32-pe/
;   
;  Assembled with yasm 1.3.0 for Win64
;    https://yasm.tortall.net/Download.html
; 
;  .\yasm-1.3.0-win64.exe -fbin -o"out.exe" source.asm
;
bits 32

LoadLibraryA            equ  0x01364564
Sleep                   equ  0xD9972F53
MessageBoxA             equ  0x36AEF1A0
ChangeDisplaySettingsA  equ  0x96F0EC1C
ShowCursor              equ  0x6D065389
ExitProcess             equ  0x665640AC
CreateWindowExA         equ  0xAFDFBED6
GetDC                   equ  0xCBD22477
ChoosePixelFormat       equ  0xA74979EF
SetPixelFormat          equ  0x19CADE93
wglCreateContext        equ  0xF2BF3662
wglMakeCurrent          equ  0x7DFD750F
wglSwapLayerBuffers     equ  0xD765358D
wglGetProcAddress       equ  0x255E1FB7
glRects                 equ  0x458B2E59
GetProcessHeap          equ  0x100E6A8D
HeapAlloc               equ  0x50B06755
timeGetTime             equ  0xFA9D45D3
GetAsyncKeyState        equ  0x247C888E 

%define  opengl32base             ebp-4
%define  kernel32base             ebp-8
%define  user32base               ebp-12
%define  gdi32base                ebp-16
%define  hWnd                     ebp-20
%define  hDC                      ebp-24
%define  oglCreateShaderProgramv  ebp-28
%define  oglGenProgramPipelines   ebp-32
%define  oglBindProgramPipeline   ebp-36
%define  oglUseProgramStages      ebp-40
%define  oglProgramUniform1f      ebp-44
%define  vertShader               ebp-48
%define  fragShader               ebp-52
%define  shaderProgram            ebp-56
%define  hHeap                    ebp-60
%define  vertAlloc                ebp-64
%define  startTime                ebp-68
%define  winmmbase                ebp-72
%define  curTime                  ebp-76
%define  __unused_var__           ebp-80

STACK_LOCALS_SIZE  equ  80

XRES  equ  1280
YRES  equ   720
DEMO_LENGTH  equ  100000

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
        dd RVA(begin)                 ; entry point address
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
dd1000: dd 1000                       ; [UNUSED-4] checksum,  Stores 1000 so we can turn millis in to secs.
        dw 3                          ; subsystem = 2:GUI  3:Console
        dw 0                          ; [UNUSED-2] DLL characteristics
        dd 0x00100000                 ; maximum stack size
        dd 0x00001000                 ; initial stack size
        dd 0x00100000                 ; maximum heap size
        dd 0x00001000                 ; initial heap size
        dd 10000                      ; [UNUSED-4] loader flags
        dd 0                          ; number of data directory entries (= none!)

; FUNCTION that calls procedure [esi] in library at base [ebx]. DWORD return values come back in [eax]
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

begin:
        mov eax, [fs:0x30]            ; get PEB pointer from TEB
        mov eax, [eax+0x0C]           ; get PEB_LDR_DATA pointer from PEB
        mov eax, [eax+0x14]           ; go to first LDR_DATA_TABLE_ENTRY
        sub esp, STACK_LOCALS_SIZE    ; save on the stack for local var
        mov eax, [eax]                ; go to where ntdll.dll typically is
        mov eax, [eax]                ; go to where kernel32.dll typically is
        mov ebx, [eax+0x10]           ; load base address of the library
        mov [kernel32base], ebx       ; store kernel32's base address

;=====  Beginning of application code  ============================================================

    ; user32base = LoadLibraryA( "user32.dll" );
        ; assume ebx = [kernel32base]
        mov esi, LoadLibraryA
        push str_user32
        call call_import
        mov [user32base], eax

    ; opengl32base = LoadLibraryA( "opengl32.dll" );
        push str_opengl32
        call call_import
        mov [opengl32base], eax

    ; gdi32base = LoadLibraryA( "gdi32.dll" );
        push str_gdi32
        call call_import
        mov [gdi32base], eax

    ; winmmbase = LoadLibraryA( "winmm.dll" );
        push str_winmm
        call call_import
        mov [winmmbase], eax

    ; ChangeDisplaySettingsA( &screenSettings, CDS_FULLSCREEN );
        push 4
        push displaySettings
        mov ebx, [user32base]
        mov esi, ChangeDisplaySettingsA
        call call_import

    ; ShowCursor( 0 );
        push 0
        mov ebx, [user32base]
        mov esi, ShowCursor
        call call_import

    ; HWND hWnd = CreateWindowExA( 0L, (LPCSTR)0xC018, 0, WS_POPUP | WS_VISIBLE, 0, 0, XRES, YRES, 0, 0, 0, 0 );
        push 0
        push 0
        push 0
        push 0
        push YRES
        push XRES
        push 0
        push 0
        push (0x80000000 | 0x10000000)
        push 0
        push 0xC018
        push 0
        mov ebx, [user32base]
        mov esi, CreateWindowExA
        call call_import
        mov [hWnd], eax

    ; HDC hDC = GetDC( hWnd );
        push eax
        mov ebx, [user32base]
        mov esi, GetDC
        call call_import
        mov [hDC], eax

    ; if( !SetPixelFormat( hDC, ChoosePixelFormat( hDC, &pfd ), &pfd )) return;
        mov ecx, [hDC]
        push ecx
        push pixelFormatDescriptor
        push ecx
        mov ebx, [gdi32base]
        mov esi, ChoosePixelFormat
        call call_import
        pop ecx
        push pixelFormatDescriptor
        push eax
        push ecx
        mov esi, SetPixelFormat
        call call_import
        or eax, eax
        jz error

    ; wglMakeCurrent( hDC, wglCreateContext( hDC ));
        mov ecx, [hDC]
        push ecx
        push ecx
        mov ebx, [opengl32base]
        mov esi, wglCreateContext
        call call_import
        pop ecx
        push eax
        push ecx
        mov esi, wglMakeCurrent
        call call_import
        or eax, eax
        jz error

    ; oglFUNCTION = wglGetProcAddress( str_glFUNCTION )
        ; assume ebx = [opengl32base]
        mov esi, wglGetProcAddress
        push str_glCreateShaderProgramv
        call call_import
        mov [oglCreateShaderProgramv], eax
        push str_glGenProgramPipelines
        call call_import
        mov [oglGenProgramPipelines], eax
        push str_glBindProgramPipeline
        call call_import
        mov [oglBindProgramPipeline], eax
        push str_glUseProgramStages
        call call_import
        mov [oglUseProgramStages], eax
        push str_glProgramUniform1f
        call call_import
        mov [oglProgramUniform1f], eax

    ; vertShader = oglCreateShaderProgramv( GL_VERTEX_SHADER, 1, str_vertexShader )
        mov dword [vertShader], str_vertexShader
        mov eax, ebp
        sub eax, 48
        push eax
        push 1
        push 0x8B31
        call [oglCreateShaderProgramv]
        mov [vertShader], eax
        test eax, eax
        jz error

    ; fragShader = oglCreateShaderProgramv( GL_FRAGMENT_SHADER, 1, str_fragmentShader )
        mov dword [fragShader], str_fragmentShader
        mov eax, ebp
        sub eax, 52
        push eax
        push 1
        push 0x8B30
        call [oglCreateShaderProgramv]
        mov [fragShader], eax
        test eax, eax
        jz error

    ; oglGenProgramPipelines( 1, &shaderProgram );
        lea eax, [shaderProgram]
        push eax
        push 1
        call [oglGenProgramPipelines]

    ; oglBindProgramPipeline( shaderProgram );
        push dword [shaderProgram]
        call [oglBindProgramPipeline]

    ; oglUseProgramStages( shaderProgram, GL_VERTEX_SHADER_BIT (1), vertShader );
        mov eax, [vertShader]
        push eax
        push 1
        mov eax, [shaderProgram]
        push eax
        call [oglUseProgramStages]

    ; oglUseProgramStages( shaderProgram, GL_FRAGMENT_SHADER_BIT (2), fragShader );
        mov eax, [fragShader]
        push eax
        push 2
        mov eax, [shaderProgram]
        push eax
        call [oglUseProgramStages]

    ; startTime = timeGetTime();
        mov ebx, [winmmbase]
        mov esi, timeGetTime
        call call_import
        mov dword [startTime], eax

    ; for( ;; ) {
drawLoop:

        ; if( (curTime = timeGetTime() - startTime) > END_TIME ) break;
            mov ebx, [winmmbase]
            mov esi, timeGetTime
            call call_import
            sub eax, dword [startTime]
            cmp eax, DEMO_LENGTH
            jg exit
            mov [curTime], eax
            fild dword [curTime]
            fidiv dword [dd1000]
            fst dword [curTime]

        ; glProgramUniform1f( fragShader, 0, curTime );
            push dword [curTime]
            push 0
            push dword [fragShader]
            call [oglProgramUniform1f]

        ; glRects( -1, -1, 1, 1 );
            push 1
            push 1
            push -1
            push -1
            mov ebx, [opengl32base]
            mov esi, glRects
            call call_import

        ; wglSwapLayerBuffers( hDC, WGL_SWAP_MAIN_PLANE );
            push 1
            push dword [hDC]
            mov ebx, [opengl32base]
            mov esi, wglSwapLayerBuffers
            call call_import

        ; if( GetAsyncKeyState( VK_ESCAPE ) ) break;
            push 0x1B
            mov ebx, [user32base]
            mov esi, GetAsyncKeyState
            call call_import
            or eax, eax
            jz drawLoop
    ; }

exit:
    ; ExitProcess( 0 );
        push 0
        mov ebx, [kernel32base]
        mov esi, ExitProcess
        call call_import


error:
    ; MessageBoxA( NULL, str_errorMessage, "", 0 );
        push 0
        push dw_zero
        push str_errorMessage
        push 0
        mov ebx, [user32base]
        mov esi, MessageBoxA
        call call_import
        jmp exit

;=====  Data section  =============================================================================


str_user32:                  db "user32.dll",0
str_errorMessage:            db "Error!", 0
str_opengl32:                db "opengl32.dll", 0
str_gdi32:                   db "gdi32.dll", 0
str_winmm:                   db "winmm.dll", 0
str_glCreateShaderProgramv:  db "glCreateShaderProgramv", 0
str_glGenProgramPipelines:   db "glGenProgramPipelines", 0
str_glBindProgramPipeline:   db "glBindProgramPipeline", 0
str_glUseProgramStages:      db "glUseProgramStages", 0
str_glProgramUniform1f:      db "glProgramUniform1f", 0

%include "shaders.asm"

displaySettings:
        dd 0                ; BYTE dmDeviceName[32];
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0

        dw 0                ; dmSpecVersion;
        dw 0                ; dmDriverVersion;
        dw 156              ; dmSize;
        dw 0                ; dmDriverExtra;
        dd 0x001c0000       ; dmFields;

        ; UNION display only fields
        dd 0                ; dmPosition.x
        dd 0                ; dmPosition.y
        dd 0                ; dmDisplayOrientation
        dd 0                ; dmDisplayFixedOutput

        dw 0                ; dmColor
        dw 0                ; dmDuplex
        dw 0                ; dmYResolution
        dw 0                ; dmTTOption
        dw 0                ; dmCollate
        
        dd 0                ; BYTE dmFormName[32];
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0
        dd 0

        dw    0             ; dmLogPixels
        dd   32             ; dmBitsPerPel
        dd 1280             ; dmPelsWidth
        dd  720             ; dmPelsHeight
        dd    0             ; UNION dmDisplayFlags | dmNup
        dd    0             ; dmDisplayFrequency

        dd 0                ; dmICMMethod
        dd 0                ; dmICMIntent
        dd 0                ; dmMediaType
        dd 0                ; dmDitherType
        dd 0                ; dmReserved1
        dd 0                ; dmReserved2

        dd 0                ; dmPanningWidth
        dd 0                ; dmPanningHeight

pixelFormatDescriptor:
        dw 40               ; nSize = sizeof(PIXELFORMATDESCRIPTOR)
        dw 1                ; nVersion
        dd (4 | 0x20 | 1),  ; dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER
        db 0                ; iPixelType = PFD_TYPE_RGBA
        db 32               ; cColorBits

        db 0                ; cRedBits
        db 0                ; cRedShift
        db 0                ; cGreenBits
        db 0                ; cGreenShift
        db 0                ; cBlueBits
        db 0                ; cBlueShift

        db 8                ; cAlphaBits

        db 0                ; cAlphaShift
        db 0                ; cAccumBits
        db 0                ; cAccumRedBits
        db 0                ; cAccumGreenBits
        db 0                ; cAccumBlueBits
        db 0                ; cAccumAlphaBits

        db 32               ; cDepthBits

        db 0                ; cStencilBits
        db 0                ; cAuxBuffers
        db 0                ; iLayerType = PFD_MAIN_PLANE
        db 0                ; bReserved

        dd 0                ; DWORD dwLayerMask
        dd 0                ; DWORD dwVisibleMask
        dd 0                ; DWORD dwDamageMask

;==================================================================================================

align ALIGNMENT, db 0
the_end: