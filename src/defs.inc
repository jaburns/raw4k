; Used in loader + payload
%define kernel32base             ebp-16
%define callImport               ebp-20

; Used in payload
%define dataPtr                  ebp-128
%define opengl32base             ebp-128-4
%define user32base               ebp-128-12
%define gdi32base                ebp-128-16
%define hWnd                     ebp-128-20
%define hDC                      ebp-128-24
%define oglCreateShaderProgramv  ebp-128-28
%define oglGenProgramPipelines   ebp-128-32
%define oglBindProgramPipeline   ebp-128-36
%define oglUseProgramStages      ebp-128-40
%define oglProgramUniform1i      ebp-128-44
%define vertShader               ebp-128-48
%define fragShader               ebp-128-52
%define shaderProgram            ebp-128-56
%define synthTEMP                ebp-128-60
%define startTime                ebp-128-68
%define winmmbase                ebp-128-72
%define curTime                  ebp-128-76
%define audioBufferAddress       ebp-128-80

; Size of the shared loader + payload stack frame
BASE_STACK_SIZE  equ  256

; Hashes of DLL function names
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
VirtualAlloc            equ  0x57F34BD3
CreateFileA             equ  0x5023E3C4
ReadFile                equ  0xF0B5A43F
sndPlaySoundA           equ  0x58DF7954


; Intro configuration
XRES         equ    1280
YRES         equ     720
DEMO_LENGTH  equ  100000  ; millis
