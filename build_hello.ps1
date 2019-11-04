# https://yasm.tortall.net/Download.html
tools\yasm-1.3.0-win64.exe -l doge.txt -fwin32 src\hello.asm

tools\yasm-1.3.0-win64.exe -l list.txt -fbin src\shell.asm

&"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\link.exe" `
    /OUT:hello.exe `
    /LIBPATH:"C:\Program Files (x86)\Windows Kits\10\Lib\10.0.17763.0\um\x86" `
    /MACHINE:X86 `
    /SUBSYSTEM:CONSOLE `
    kernel32.lib user32.lib `
    hello.obj