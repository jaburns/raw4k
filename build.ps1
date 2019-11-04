mkdir -Force bin
node tools\packShaders.js
tools\yasm-1.3.0-win64.exe -fbin -o"bin\raw4k.exe" src\source.asm