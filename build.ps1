param ( [switch]$debug )

node tools\packShaders.js
tools\yasm-1.3.0-win64.exe -o"bin\payload.bin" -l"bin\payload.lst" -fbin src\payload.asm

if ($debug) {
    tools\yasm-1.3.0-win64.exe -D"DEBUG" -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
} else {
    node .\tools\zip.js
    tools\yasm-1.3.0-win64.exe -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
}