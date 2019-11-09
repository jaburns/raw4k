#!/usr/bin/env node
const fs = require('fs');

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

const translatePTRorOFFSET = (line, kind) => {
    const register =
        line.match(/[ ,]al[ ,]/) || line.match(/[ ,]ah[ ,]/) || line.match(/[ ,]ax[ ,]/) || line.match(/[ ,]eax[ ,]/)
        ? 'ebx' : 'eax';

    let label, newInstruction;

    if (kind === 'PTR') {
        label = line.match(/PTR [^ ,]+/)[0].replace('PTR ', '');
        newInstruction = line.replace(/PTR [^ ,]+/, `[${register}]`);
    } else {
        label = line.match(/OFFSET [^ ,]+/)[0].replace('OFFSET ', '');
        newInstruction = line.replace(/OFFSET [^ ,]+/, `${register}`);
    }

    const touchesStack = newInstruction.indexOf('push') >= 0
        || newInstruction.indexOf('pop') >= 0
        || newInstruction.indexOf('esp') >= 0;

    return [
        touchesStack ? `mov dword [synthTEMP], ${register}` : `push ${register}`,
        `pextrd ${register}, xmm0, 0`,
        `add ${register}, ${label} - data_start`,
        newInstruction,
        touchesStack ? `mov ${register}, dword [synthTEMP]` : `pop ${register}`
    ];
};

const translateTextSeg = lines => {
    let collectingVars = true;
    const vars = {};
    const outLines = [];

    for (;;) {
        const line = lines.shift().replace(/;.*$/, '').trim();

        if (line.indexOf(' PROC') >= 0) {
            let procName = line.substr(0, line.indexOf(' PROC'));
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

        line = line.replace('PTR [', '[');
        line = line.replace('SHORT ', '');
        line = line.replace(/[\$@]/g, '');
        line = line.replace('ret 0', 'ret');
        line = line.replace(/ST\((.)\)/g, 'st$1');

        if (line.indexOf(' PTR ') >= 0) {
            Array.prototype.push.apply(outLines, translatePTRorOFFSET(line, 'PTR').map(x => '        '+x));
        }
        else if (line.indexOf(' OFFSET ') >= 0) {
            Array.prototype.push.apply(outLines, translatePTRorOFFSET(line, 'OFFSET').map(x => '        '+x));
        }
        else {
            if (line.endsWith(':')) {
                line = '    '+line;
            } else {
                line = '        '+line;
            }

            outLines.push(line);
        }
    }

    return outLines.join('\n');
};

const translateCode = segs =>
    segs.map(translateTextSeg).join('\n\n\n');

const lines = fs.readFileSync('./synth/Release/synth.asm', 'utf8')
    .split('\n')
    .map(x => x.replace(/[\t\r\n ]+/g, ' ').trim())
    .filter(x => !x.startsWith(';'));

const segs = getSegments(lines);

fs.writeFileSync('./src/synthData.inc', translateData(segs.constLines));
fs.writeFileSync('./src/synthCode.inc', translateCode(segs.textSegs));