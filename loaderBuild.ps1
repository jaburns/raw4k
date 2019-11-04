tools\yasm-1.3.0-win64.exe -o"code.bin" -l code.txt -fbin src\code.asm

tools\yasm-1.3.0-win64.exe -o"loader.obj" -l loader.txt -fwin32 src\loader.asm

&"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\link.exe" `
    /OUT:loader.exe `
    /MACHINE:X86 `
    /SUBSYSTEM:CONSOLE `
    loader.obj