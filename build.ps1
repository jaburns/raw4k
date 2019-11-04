# https://yasm.tortall.net/Download.html

mkdir -Force bin

node tools\packShaders.js

tools\yasm-1.3.0-win64.exe -o"bin\payload.bin" -l"bin\payload.lst" -fbin src\payload.asm

tools\yasm-1.3.0-win64.exe -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm