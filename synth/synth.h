#pragma once

#define AUDIO_DURATION       50
#define AUDIO_RATE        44100
#define AUDIO_NUMCHANNELS     2
#define AUDIO_NUMSAMPLES  (AUDIO_DURATION * AUDIO_RATE)
#define WAVE_FORMAT_PCM       1
#define SIZEOF_WORD           2

void __stdcall runSynth( short *buffer );
