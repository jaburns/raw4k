#define AUDIO_DURATION        5
#define AUDIO_RATE        44100
#define AUDIO_NUMCHANNELS     2
#define AUDIO_NUMSAMPLES  (AUDIO_DURATION * AUDIO_RATE)

const short buffer[];

static int f2i( float x )
{
    int tmp;
    _asm {
        fld dword ptr[x]
        fistp dword ptr[tmp];
    }
    return tmp;
}

void audioInit( short *buffer )
{
    for ( int i = 0; i < AUDIO_NUMSAMPLES; ++i )
    {
        const float amplitude = sin( 2.0f * 3.14159f * 440.0f * (float)i/(float)AUDIO_RATE );
        buffer[2*i+0] = f2i(amplitude*32767.0f);
        buffer[2*i+1] = f2i(amplitude*32767.0f);
    }
}
