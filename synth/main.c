#define WIN32_LEAN_AND_MEAN
#define WIN32_EXTRA_LEAN
#include <windows.h>
#include <mmsystem.h>
#include <stdio.h>
#include <stdint.h>
#include "synth.h"

void __stdcall runSynth( short *buffer );

static const int wavHeader[11] = {
    0x46464952, 
    AUDIO_NUMSAMPLES*2 + 36, 
    0x45564157, 
    0x20746D66, 
    16, 
    WAVE_FORMAT_PCM | (AUDIO_NUMCHANNELS << 16), 
    AUDIO_RATE, 
    AUDIO_RATE * AUDIO_NUMCHANNELS * SIZEOF_WORD,
    (AUDIO_NUMCHANNELS * SIZEOF_WORD) | ((8 * SIZEOF_WORD) << 16),
    0x61746164, 
    AUDIO_NUMSAMPLES * SIZEOF_WORD
};

int main()
{
    uint8_t *audioBufferAddress = malloc( 4 * AUDIO_NUMSAMPLES + 44 );
    memcpy( audioBufferAddress, wavHeader, 44 );
    runSynth( audioBufferAddress + 44 );
    sndPlaySound( audioBufferAddress, SND_SYNC | SND_MEMORY );
    return 0;
}
