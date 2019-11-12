#!/usr/bin/env node
const fs = require('fs');

const assumedMaxStackSize = 128;

const getSegments = lines => {
    let curSeg = '';
    let constLines = [];
    let textSegs = [];
    let curTextSeg = [];
    while (lines.length) {
        const line = lines.shift();

        switch (curSeg) {
            case 'const':
                if (line.startsWith('CONST')) {
                    curSeg = '';
                } else {
                    constLines.push(line);
                }
                break;
            case 'text':
                if (line.startsWith('_TEXT')) {
                    textSegs.push(curTextSeg);
                    curTextSeg = [];
                    curSeg = '';
                } else {
                    curTextSeg.push(line);
                }
                break;
            default:
                if (line.startsWith('CONST')) {
                    curSeg = 'const';
                } else if (line.startsWith('_TEXT')) {
                    curSeg = 'text';
                }
                break;
        }
    }
    return { constLines, textSegs };
};

const translateData = lines =>
    lines.map(x => x
        .replace(/@/g, '')
        .replace(/r ;.*/g, '')
        .replace(/H$/g, '')
        .replace(/D(.) /g, ' D$1 0x'))
    .join('\n');

const translatePTRorOFFSET = (line, kind, register) => {
    let label, newInstruction;

    if (kind === 'PTR') {
        label = line.match(/PTR [^ ,]+/)[0].replace('PTR ', '');
        newInstruction = line.replace(/PTR [^ ,]+/, `[${register}]`);
    } else {
        label = line.match(/OFFSET [^ ,]+/)[0].replace('OFFSET ', '');
        newInstruction = line.replace(/OFFSET [^ ,]+/, `${register}`);
    }

    return [
        `pextrd ${register}, xmm0, 0`,
        `add ${register}, ${label} - data_start`,
        newInstruction,
    ];
};

const translateTextSeg = lines => {
    let outLines = [];
    let calls = [];
    let procName = '';
    const vars = {};

    for (;;) {
        const line = lines.shift().replace(/;.*$/, '').trim();

        if (line.indexOf(' PROC') >= 0) {
            procName = line.substr(0, line.indexOf(' PROC'));
            if (procName === '_runSynth@4') procName = 'runSynth';
            outLines.push(procName + ':');
            break;
        }

        const parts = line.split('=').map(x => x.trim());
        const intPart = parseInt(parts[1]);
        vars[parts[0]] = intPart >= 0 ? `+${intPart}` : `${intPart}`;
    }

    const varExpr = /PTR ([^[]+)\[ebp]/;

    while (lines.length) {
        let line = lines.shift().replace(/;.*$/, '').trim();

        if (line.endsWith('ENDP')) break;

        const match = line.match(varExpr);
        if (match) {
            line = line.replace(varExpr, `[ebp${vars[match[1]]}]`);
        }

        if (line.indexOf('call ') >= 0) {
            calls.push(line.replace(/.*call /, '').trim());
        }

        line = line.replace('PTR [', '[');
        line = line.replace('SHORT ', '');
        line = line.replace(/[\$@]/g, '');
        line = line.replace('ret 0', 'ret');
        line = line.replace(/ST\((.)\)/g, 'st$1');

        outLines.push(line);
    }

    const registerRefCount = {
        eax: 0,
        ebx: 0,
        ecx: 0,
        edx: 0,
    };

    lines = outLines;
    outLines = [];

    const testRegister = (line, r) => !!(
           line.match(new RegExp(`[^A-Za-z0-9_]${r}l[^A-Za-z0-9_]`))
        || line.match(new RegExp(`[^A-Za-z0-9_]${r}h[^A-Za-z0-9_]`))
        || line.match(new RegExp(`[^A-Za-z0-9_]${r}x[^A-Za-z0-9_]`))
        || line.match(new RegExp(`[^A-Za-z0-9_]e${r}x[^A-Za-z0-9_]`)));

    lines.forEach(line => {
        if (testRegister(line, 'a')) registerRefCount.eax++;
        if (testRegister(line, 'b')) registerRefCount.ebx++;
        if (testRegister(line, 'c')) registerRefCount.ecx++;
        if (testRegister(line, 'd')) registerRefCount.edx++;
    });

    const scratchRegister =
        registerRefCount.eax === 0 ? 'eax' :
        registerRefCount.ebx === 0 ? 'ebx' :
        registerRefCount.ecx === 0 ? 'ecx' :
        registerRefCount.edx === 0 ? 'edx' : '';

    if (scratchRegister === '') {
        throw new Error('No unused register found in function! This case is not yet handled, aborting.');
    }

    while (lines.length) {
        let line = lines.shift();
        if (line.indexOf(' PTR ') >= 0) {
            Array.prototype.push.apply(outLines, translatePTRorOFFSET(line, 'PTR', scratchRegister));
        } else if (line.indexOf(' OFFSET ') >= 0) {
            Array.prototype.push.apply(outLines, translatePTRorOFFSET(line, 'OFFSET', scratchRegister));
        } else {
            outLines.push(line);
        }
    }

    return { procName, body: outLines.join('\n'), calls };
};

const translateCode = segs => {
    const newSegs = segs.map(translateTextSeg);

    const usedProcs = newSegs.map(x => x.calls).flat();
    usedProcs.push('runSynth');

    return newSegs
        .filter(x => usedProcs.indexOf(x.procName) >= 0)
        .map(x => x.body)
        .join('\n');
};

const lines = fs.readFileSync('./synth/Release/synth.asm', 'utf8')
    .split('\n')
    .map(x => x.replace(/[\t\r\n ]+/g, ' ').trim())
    .filter(x => !x.startsWith(';'));

const segs = getSegments(lines);

fs.writeFileSync('./src/synthData.inc', translateData(segs.constLines));
fs.writeFileSync('./src/synthCode.inc', translateCode(segs.textSegs));
