#include "synth.h"

#define sinf sin
#define PI 3.14159265358979f

static int f2i( float x )
{
    int tmp;
    _asm {
        fld dword ptr[x]
        fistp dword ptr[tmp];
    }
    return tmp;
}

static float __declspec(noinline) asmPow( float a, float b )
{
    _asm {
        fld dword ptr[b]
        fld dword ptr[a]
        fyl2x
        fist dword ptr[b]
        fild dword ptr[b]
        fsub
        f2xm1
        fld1
        fadd
        fild dword ptr[b]
        fxch
        fscale
        fstp dword ptr[a]
        fstp dword ptr[b]
        fld dword ptr[a]
    }
}

static float floorj( float x )
{
    return f2i( x - 0.5f );
}

static float clamp(float x, float lowerlimit, float upperlimit)
{
    if (x < lowerlimit) x = lowerlimit;
    if (x > upperlimit) x = upperlimit;
    return x;
}

static float smoothstep(float edge0, float edge1, float x)
{
    x = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f); 
    return x * x * (3 - 2 * x);
}

static float mix(float a, float b, float t)
{
    return a + t*(b - a);
}

static float fract(float a)
{
    return a - floorj(a);
}

static float jmod(float a, float b)
{
    return a - b * floorj( a / b );
}

#define TRACK_LEN 16

const int KICKS[] = { 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0 };
const int HATS[]  = { 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1 };

static float latestStartTime( float time, const int* track )
{
    time *= 4.0f;
    
    float result = -10.0f;
    
    for( int i = 0; i < TRACK_LEN; ++i ) {
        float t = (float)i;
        if( t >= time ) break;
        if( track[i] > 0 ) result = t;
    }
    
    return result / 4.0f;
}

static float hash( float i )
{
    return fract( sinf( i * 12.9898f ) * 43758.5453f );
}
    
static float funcRand( float x )
{
    float a = hash( floorj( x ));
    float b = hash( floorj( x + 1.0f ));
    return 1.0f - 2.0f * mix( a, b, smoothstep( 0.0f, 1.0f, fract( x )));
}

static float taylorSquareWave( float x )
{
    float result = 0.0f;
    
    for( int i = 1; i <= 5; i += 2 )
    {
        float n = (float)i;
        result += 4.0f / PI / n * sinf( n * x );
    } 
    
    return result;
}

static float kick( float time )
{
    float attack = clamp( 400.0f*time, 0.0f, 1.0f );
    float decay = 1. - smoothstep( 0.4f, 0.5f, time );
    return attack * decay * sinf( 220.0f * asmPow( time, 0.65f ));
}

static float hat( float time )
{
     return 0.33f * funcRand( 20000.0f * asmPow( 2.72f, -10.0f*time )) * asmPow( 2.72f, -30.0f*time );
}

static float padFreq( float time )
{
    float detune = 0.0f;
    if( time < 0.0f ) {
        detune = 0.0f;
    } else {
        time = jmod( time, 12.0f );        
        if( time < 2.0f ) detune = 6.3f;
        else if( time < 4.0f ) detune = 4.1f;
    }    
            
    return 32.0f * asmPow( 2.0f, detune / 12.0f );
}

static float getSound( float time )
{
    float t = jmod( time, (float)TRACK_LEN / 4. );
    
    float sineRamp = clamp((time - 4.0f) / 12.0f, 0.0f, 1.0f);
    float sqrRamp  = clamp((time - 8.0f) /  8.0f, 0.0f, 1.0f);
    
    float padF = padFreq( time );
    
    float signal =
        1.00f * kick( t - latestStartTime( t, KICKS )) +
        0.50f * hat( t - latestStartTime( t, HATS )) +
        0.25f * sqrRamp * taylorSquareWave( 2.0f * PI * (padF + 2.0f) * time ) +
        0.50f * sineRamp * sinf( 4.0f * PI * padF * time );
    
    return clamp( signal, -1.0f, 1.0f );
}

void __stdcall runSynth( short *buffer )
{
    for( int i = 0; i < AUDIO_NUMSAMPLES; i++ ) 
    {
        const float amplitude = getSound( (float)i/(float)AUDIO_RATE );
        buffer[2*i+0] = f2i(amplitude*32767.0f);
        buffer[2*i+1] = f2i(amplitude*32767.0f);
    }
}
