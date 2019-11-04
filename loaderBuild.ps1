mkdir -Force bin

node tools\packShaders.js

tools\yasm-1.3.0-win64.exe -o"bin\code.bin" -l"bin\code.txt" -fbin src\code.asm

tools\yasm-1.3.0-win64.exe -o"bin\loader.obj" -l"bin\loader.txt" -fwin32 src\loader.asm

&"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\link.exe" `
    /OUT:"bin\loader.exe" `
    /MACHINE:X86 `
    /SUBSYSTEM:CONSOLE `
    "bin\loader.obj"