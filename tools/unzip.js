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

    let size0 = buffer[i++];
    let size1 = buffer[i++];
    let size = size0 + 256*size1;
    console.log(size0, size1);
    let j = i;

    let outBytes = [];
    while (i - j < size) {
        let byte = buffer[i++];
        if (byte == 0xFF) {
            Array.prototype.push.apply(outBytes, dict[buffer[i++]]);
        } else {
            outBytes.push(byte);
        }
    }

    return Buffer.from(outBytes);
};

const inputBuffer = fs.readFileSync('compressed.bin');
const result = unzip(inputBuffer);

fs.writeFileSync('outjs.exe', result);