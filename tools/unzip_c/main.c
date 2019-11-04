#include <stdio.h>
#include <stdint.h>

// TODO fread
const char DATA[] = { };

extern int unzip( char *outBuffer, const char *data );

int main()
{
    char buffer[32678];
    int outSize = unzip(&buffer[0], DATA);
    FILE *fp = fopen("outc.exe", "wb");
    fwrite(buffer, 1, outSize, fp);
    fclose(fp);
    return 0;
}
