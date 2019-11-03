#include <string.h>
#include <stdint.h>
#include <stdio.h>

int unzip( uint8_t *outBuffer, const uint8_t *data )
{
    uint8_t *dictLocs[256];

    uint8_t *p = data;
    uint8_t *o = outBuffer;

    int dictSize = *p++;

    for(int i = 0; i < dictSize; ++i)
    {
        dictLocs[i] = p;
        p += *p + 1;
    }

    int size = *(uint16_t*)p;
    p += 2;
    uint8_t *endAddress = p + size;
    int outSize = 0;

    while( p < endAddress )
    {
        uint8_t byte = *p++;
        if( byte == 0xFF ) {
            uint8_t *q = dictLocs[*p++];
            int count = *q++;
            while (count > 0) {
                *o++ = *q++;
                outSize++;
                count--;
            }
        } else {
            *o++ = byte;
            outSize++;
        }
    }

    return outSize;
}