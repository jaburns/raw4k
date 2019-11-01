const fs = require('fs');

const OPERATORS = '+-*/=(){};,<>?:';

const getFunctionNames = s =>
    [...s.matchAll(/^[^\n ]* [^ ]* *\([^\)]*\) *$/gm)]
    .map(x => {
        let a = x[0].substr(0, x[0].indexOf('('));
        return a.substr(a.lastIndexOf(' ') + 1);
    })
    .filter(x => x !== 'main');

const oneLine = s =>
    s.split('\n')
    .map(x => x.trim())
    .filter(x => !x.startsWith('//'))
    .join('');

const packSpaces = s => {
    OPERATORS.split('').forEach(o => {
        s = s.replace(new RegExp(`([^ ]) *\\${o} *([^ ])`, 'g'), '$1'+o+'$2');
    });
    return s;
};

const pack = s => {
    console.log(getFunctionNames(s));
    return packSpaces(oneLine(s));
}

const vert = pack(fs.readFileSync('shader.vert', 'utf8'));
const frag = pack(fs.readFileSync('shader.frag', 'utf8'));

console.log(frag);

fs.writeFileSync('shaders.asm', `
str_vertexShader:
        db "#version 430",10,"${vert}",0
str_fragmentShader:
        db "#version 430",10,"${frag}", 0
`);
