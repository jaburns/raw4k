#!/usr/bin/env node
const fs = require('fs');

const unzip = buffer => {
    let dict = [];
    let i = 0;

    let dictSize = buffer[i++];

    while (dictSize > 0) {
        let tokenSize = buffer[i++];
        dict.push(buffer.subarray(i, i + tokenSize));
        i += tokenSize;
        dictSize--;
    }

    let outBytes = [];
    while (i < buffer.length) {
        let byte = buffer[i++];
        if (byte == 0xFF) {
            Array.prototype.push.apply(outBytes, dict[buffer[i++]]);
        } else {
            outBytes.push(byte);
        }
    }

    return Buffer.from(outBytes);
};

const inputBuffer = fs.readFileSync('./bin/payload.z');
const result = unzip(inputBuffer);
fs.writeFileSync('./bin/payload.bin.unz', result);