param ( [switch]$debug )

mkdir -Force bin/ | Out-Null

echo 'Translating assembly listing for synth...'
node tools\linkSynth.js

echo 'Packing GLSL shaders...'
node tools\packShaders.js

echo 'Assembling payload binary...'
tools\yasm-1.3.0-win64.exe -o"bin\payload.bin" -l"bin\payload.lst" -fbin src\payload.asm

if ($debug) {
    echo 'Assembling final executable...'
    tools\yasm-1.3.0-win64.exe -D"DEBUG" -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
} else {
    echo 'Compressing payload...'
    node .\tools\zip.js

    echo 'Assembling final executable...'
    tools\yasm-1.3.0-win64.exe -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
}

ls .\bin\intro.exe
