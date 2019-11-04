#!/usr/bin/env node

const fs = require('fs');

class BufferString {
    constructor(s) {
        if (typeof s === 'string') {
            this.buffer = Buffer.from(s);
        } else {
            this.buffer = s;
        }
    }

    get length() {
        return this.buffer.length;
    }

    substr(a, b) {
        return new BufferString(this.buffer.subarray(a, a+b));
    }

    split(a) {
        const lines = [];
        let buf = this.buffer;
        let search = -1;
        while( (search = buf.indexOf(a.buffer)) > -1) {
            lines.push(buf.slice(0, search));
            buf = buf.slice(search + a.buffer.length, buf.length);
        }
        lines.push(buf);
        return lines.map(x => new BufferString(x));
    }

    static join(arr, delim) {
        const cat = [];
        if (!delim) delim = new BufferString('');

        for (let i = 0; i < arr.length; ++i) {
            cat.push(arr[i].buffer);
            if (i < arr.length - 1) cat.push(delim.buffer);
        }

        return new BufferString(Buffer.concat(cat));
    }

    static equals(a, b) {
        return a.buffer.equals(b.buffer);
    }

    toString() {
        return this.buffer.toString('utf8');
    }
}

const getScore = (lengthToReplace, lengthInDict, count) => {
    const compressedSize = 2*count + lengthInDict+1;
    const currentSize = count * lengthToReplace;
    const gain = currentSize - compressedSize;

    return gain;
};

const compress = buffer => {
    let str = new BufferString(buffer);
    let matches = [];

    for (let w = Math.floor(str.length / 3); w >= 3; w--) {
        for (let i = 0; i <= str.length - w; i++) {
            const A = str.substr(i, w);
            const copies = str.split(A).length - 1;
            if (copies >= 2) {
                matches = matches.filter(x => !BufferString.equals(x.key, A));
                matches.push({ key: A, copies });
            }
        }
    }

    let scoredMatches = [];
    for (let i = 0; i < matches.length; ++i) {
        const k = matches[i].key;
        const score = getScore(k.length, k.length, matches[i].copies);
        scoredMatches.push([k, score, k]);
    }
    scoredMatches.sort((a, b) => b[1] - a[1]);
    scoredMatches = scoredMatches.filter(x => x[1] >= 1);

    const FF = new BufferString(Buffer.from([ 0xFF ]));
    scoredMatches.unshift([FF, 1000, FF]);

    let replacedLookup = [];
    let replacedLookupIndex = 0;

    while(scoredMatches.length > 0) {
        const match = scoredMatches.shift();
        const token = new BufferString(Buffer.from([ 0xFF, replacedLookupIndex++ ]));
        str = BufferString.join(str.split(match[0]), token);
        replacedLookup.push(Buffer.from([ match[2].length ]));
        replacedLookup.push(match[2].buffer);

        for (let i = 0; i < scoredMatches.length; ++i) {
            const otherMatch = scoredMatches[i];
            otherMatch[0] = BufferString.join(otherMatch[0].split(match[0]), token);
            otherMatch[1] = getScore(otherMatch[0].length, otherMatch[2].length, str.split(otherMatch[0]).length - 1);
        }

        scoredMatches.sort((a, b) => b[1] - a[1]);
        scoredMatches = scoredMatches.filter(x => x[1] >= 1);
    }

    replacedLookup.unshift(Buffer.from([ replacedLookup.length / 2 ]));
    const dictionary = new BufferString(Buffer.concat(replacedLookup));
//  const strLen = new BufferString(Buffer.from([ str.length % 256, Math.floor(str.length / 256) ]));
    return BufferString.join([ dictionary, str ]).buffer;
};

const inputBuffer = fs.readFileSync('bin/payload.bin');
const result = compress(inputBuffer);
// const bytes = [];
// Array.prototype.push.apply(bytes, result);
// fs.writeFileSync('bin/payload.h', `const char DATA[] = { ${bytes.join(',')} };`);
fs.writeFileSync('bin/payload.z', result);





















