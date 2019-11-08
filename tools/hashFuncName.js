#!/usr/bin/env node

const hash = string => {
    const ror7 = x => ((x >>> 7) | ((x & 0x7F) << (32 - 7))) >>> 0;
    let hash = 0;

    for (let i = string.length - 1; i >= 0; --i) {
        hash = ror7( hash );
        hash = (hash ^ string.charCodeAt(i)) >>> 0;
    }

    let ret = hash.toString( 16 );
    while( ret.length < 8 ) ret = '0' + ret;
    return '0x' + ret.toUpperCase();
};

console.log(hash(process.argv[2]));