param ( [switch]$debug )

mkdir -Force bin/ | Out-Null

Write-Output 'Translating assembly listing for synth...'
node tools\linkSynth.js

Write-Output 'Packing GLSL shaders...'
.\tools\shader_minifier.exe --format nasm src/shader.vert -o tmp.h
Get-Content tmp.h | Out-File -Encoding "ASCII" .\src\shaders.inc
.\tools\shader_minifier.exe --format nasm src/shader.frag -o tmp.h
Get-Content tmp.h | Out-File -Encoding "ASCII" -Append .\src\shaders.inc
Remove-Item .\tmp.h

Write-Output 'Assembling payload binary...'
tools\yasm-1.3.0-win64.exe -o"bin\payload.bin" -l"bin\payload.lst" -fbin src\payload.asm

if ($debug) {
    Write-Output 'Assembling final executable...'
    tools\yasm-1.3.0-win64.exe -D"DEBUG" -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
} else {
    Write-Output 'Compressing payload...'
    node .\tools\zip.js

    Write-Output 'Assembling final executable...'
    tools\yasm-1.3.0-win64.exe -o"bin\intro.exe" -l"bin\loader.lst" -fbin src\loader.asm
}

Get-ChildItem .\bin\intro.exe
