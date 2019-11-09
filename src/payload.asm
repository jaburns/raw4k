;======================================================================================================
;  Intro payload, compressed and embedded in final EXE
;
BITS 32

%include "defs.inc"

%macro loadVar 1
        mov eax, [dataPtr]
        add eax, (%1 - data_start)
%endmacro

%macro pushVar 1
        mov eax, [dataPtr]
        add eax, (%1 - data_start)
        push eax
%endmacro

pre_start:
        call start

data_start:

str_user32:                  db "user32.dll",0
str_opengl32:                db "opengl32.dll", 0
str_gdi32:                   db "gdi32.dll", 0
str_winmm:                   db "winmm.dll", 0
str_glCreateShaderProgramv:  db "glCreateShaderProgramv", 0
str_glGenProgramPipelines:   db "glGenProgramPipelines", 0
str_glBindProgramPipeline:   db "glBindProgramPipeline", 0
str_glUseProgramStages:      db "glUseProgramStages", 0
str_glProgramUniform1i:      db "glProgramUniform1i"
str_empty:                   db 0

%include "shaders.inc"
%include "synthData.inc"

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

%define AUDIO_DURATION       50
%define AUDIO_RATE        44100
%define AUDIO_NUMCHANNELS     2
%define AUDIO_NUMSAMPLES  (AUDIO_DURATION * AUDIO_RATE)
%define WAVE_FORMAT_PCM       1
%define SIZEOF_WORD           2

wavHeader:
        dd 0x46464952
        dd AUDIO_NUMSAMPLES*2 + 36, 
        dd 0x45564157, 
        dd 0x20746D66, 
        dd 16, 
        dd WAVE_FORMAT_PCM | (AUDIO_NUMCHANNELS << 16), 
        dd AUDIO_RATE, 
        dd AUDIO_RATE * AUDIO_NUMCHANNELS * SIZEOF_WORD,
        dd (AUDIO_NUMCHANNELS * SIZEOF_WORD) | ((8 * SIZEOF_WORD) << 16),
        dd 0x61746164, 
        dd AUDIO_NUMSAMPLES * SIZEOF_WORD

start:
        pop eax
        mov [dataPtr], eax

        mov ebx, [kernel32base]
        mov esi, LoadLibraryA

    ; user32base = LoadLibraryA( "user32.dll" );
        pushVar str_user32
        call [callImport]
        mov [user32base], eax

    ; opengl32base = LoadLibraryA( "opengl32.dll" );
        pushVar str_opengl32
        call [callImport]
        mov [opengl32base], eax

    ; gdi32base = LoadLibraryA( "gdi32.dll" );
        pushVar str_gdi32
        call [callImport]
        mov [gdi32base], eax

    ; winmmbase = LoadLibraryA( "winmm.dll" );
        pushVar str_winmm
        call [callImport]
        mov [winmmbase], eax

    ; ChangeDisplaySettingsA( &screenSettings, CDS_FULLSCREEN );
        push 4
        pushVar displaySettings
        mov ebx, [user32base]
        mov esi, ChangeDisplaySettingsA
        call [callImport]

    ; ShowCursor( 0 );
        push 0
        mov ebx, [user32base]
        mov esi, ShowCursor
        call [callImport]

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
        call [callImport]
        mov [hWnd], eax

    ; HDC hDC = GetDC( hWnd );
        push eax
        mov ebx, [user32base]
        mov esi, GetDC
        call [callImport]
        mov [hDC], eax

    ; if( !SetPixelFormat( hDC, ChoosePixelFormat( hDC, &pfd ), &pfd )) return;
        mov ecx, [hDC]
        push ecx
        pushVar pixelFormatDescriptor
        push ecx
        mov ebx, [gdi32base]
        mov esi, ChoosePixelFormat
        call [callImport]
        pop ecx
        mov edx, eax
        pushVar pixelFormatDescriptor
        push edx
        push ecx
        mov esi, SetPixelFormat
        call [callImport]

    ; wglMakeCurrent( hDC, wglCreateContext( hDC ));
        mov ecx, [hDC]
        push ecx
        push ecx
        mov ebx, [opengl32base]
        mov esi, wglCreateContext
        call [callImport]
        pop ecx
        push eax
        push ecx
        mov esi, wglMakeCurrent
        call [callImport]

    ; oglFUNCTION = wglGetProcAddress( str_glFUNCTION )
        ; assume ebx = [opengl32base]
        mov esi, wglGetProcAddress
        pushVar str_glCreateShaderProgramv
        call [callImport]
        mov [oglCreateShaderProgramv], eax
        pushVar str_glGenProgramPipelines
        call [callImport]
        mov [oglGenProgramPipelines], eax
        pushVar str_glBindProgramPipeline
        call [callImport]
        mov [oglBindProgramPipeline], eax
        pushVar str_glUseProgramStages
        call [callImport]
        mov [oglUseProgramStages], eax
        pushVar str_glProgramUniform1i
        call [callImport]
        mov [oglProgramUniform1i], eax

    ; vertShader = oglCreateShaderProgramv( GL_VERTEX_SHADER, 1, &str_vertexShader )
        loadVar str_vertexShader
        mov dword [vertShader], eax
        mov eax, ebp
        sub eax, 128 + 48
        push eax
        push 1
        push 0x8B31
        call [oglCreateShaderProgramv]
        mov [vertShader], eax

    ; fragShader = oglCreateShaderProgramv( GL_FRAGMENT_SHADER, 1, &str_fragmentShader )
        loadVar str_fragmentShader
        mov dword [fragShader], eax
        mov eax, ebp
        sub eax, 128 + 52
        push eax
        push 1
        push 0x8B30
        call [oglCreateShaderProgramv]
        mov [fragShader], eax

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

    ; audioBufferAddress = VirtualAlloc( 0, 4 * AUDIO_NUMSAMPLES + 44, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE );
        push 4
        push 0x00001000 | 0x00002000
        push 4 * AUDIO_NUMSAMPLES + 44
        push 0
        mov ebx, [kernel32base]
        mov esi, VirtualAlloc
        call [callImport]
        mov [audioBufferAddress], eax

    ; memcpy( *audioBufferAddress, wavHeader, 44 );
        mov ecx, 11
        mov edi, dword [audioBufferAddress]
        mov esi, dword [dataPtr]
        add esi, (wavHeader - data_start)
        audioCopyLoop:
            dec ecx
            mov eax, dword [esi + 4*ecx]
            mov dword [edi + 4*ecx], eax
            jnz audioCopyLoop

    ; runSynth( *audioBufferAddress );
        mov edi, dword [audioBufferAddress]
        add edi, 44
        push edi
        movq xmm0, qword [dataPtr]
        call runSynth

    ; sndPlaySoundA( *audioBufferAddress, SND_ASYNC|SND_MEMORY );
        push 1 | 4
        push dword [audioBufferAddress]
        mov ebx, [winmmbase]
        mov esi, sndPlaySoundA
        call [callImport]

    ; startTime = timeGetTime();
    ;   mov ebx, [winmmbase]
        mov esi, timeGetTime
        call [callImport]
        mov dword [startTime], eax

    ; for( ;; ) {
drawLoop:

        ; if( (curTime = timeGetTime() - startTime) > END_TIME ) break;
            mov ebx, [winmmbase]
            mov esi, timeGetTime
            call [callImport]
            sub eax, dword [startTime]
            cmp eax, DEMO_LENGTH
            jg exit
            mov [curTime], eax

        ; glProgramUniform1i( fragShader, 0, curTime );
            push dword [curTime]
            push 0
            push dword [fragShader]
            call [oglProgramUniform1i]

        ; glRects( -1, -1, 1, 1 );
            push 1
            push 1
            push -1
            push -1
            mov ebx, [opengl32base]
            mov esi, glRects
            call [callImport]

        ; wglSwapLayerBuffers( hDC, WGL_SWAP_MAIN_PLANE );
            push 1
            push dword [hDC]
            mov ebx, [opengl32base]
            mov esi, wglSwapLayerBuffers
            call [callImport]

        ; if( GetAsyncKeyState( VK_ESCAPE ) ) break;
            push 0x1B
            mov ebx, [user32base]
            mov esi, GetAsyncKeyState
            call [callImport]
            or eax, eax
            jz drawLoop
    ; }

exit:
    ; ExitProcess( 0 );
        push 0
        mov ebx, [kernel32base]
        mov esi, ExitProcess
        call [callImport]

%include "synthCode.inc"