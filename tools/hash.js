const hash = string => {
    const ror7 = x => ((x >>> 7) | ((x & 0x7F) << (32 - 7))) >>> 0;

    let hash = 0;

    for( let index = string.length - 1; index >= 0; index-- )
    {
        hash = ror7( hash );
        hash = (hash ^ string.charCodeAt( index )) >>> 0;
    }

    let ret = hash.toString( 16 );
    while( ret.length < 8 ) ret = '0' + ret;
    return '0x' + ret.toUpperCase();
};

console.log( hash( process.argv[2] ));