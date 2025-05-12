const path = require('path');
const { execSync } = require('child_process');
const fs = require('fs').promises;

class SimpleDisassembler {
  constructor() {
    this.tools = {
      ndisasm: path.resolve('nasm/ndisasm.exe'),
      objcopy: path.resolve('mingw/objcopy.exe')
    };
  }

  async process(file) {
    const isBin = file.endsWith('.bin');
    const tempBin = isBin ? file : await this.toBinary(file);
    
    const asm = execSync(
      `"${this.tools.ndisasm}" -b32 -o0x1000000 "${tempBin}"`,
      { encoding: 'utf-8' }
    );

    const clean = this.clean(asm);
    await fs.writeFile('output.asm', this.addHeader(clean));
    
    if (!isBin) await fs.unlink(tempBin);
  }

  clean(code) {
    return code.split('\n')
      .map(line => line
        .replace(/^[\dA-F]{8}\s+[\dA-F]+\s+/i, '')
        .replace(/(dword|byte)\s*\+\s*/g, '$1 ')
        .replace(/add \[eax\],al|xor \[eax\],al/g, 'nop')
        .trim()
      )
      .filter(line => line && !line.startsWith(';'))
      .join('\n');
  }

  addHeader(code) {
    return `bits 32\n\n${code}`;
  }

  async toBinary(file) {
    const bin = `${file}.temp.bin`;
    execSync(`"${this.tools.objcopy}" -O binary "${file}" "${bin}"`);
    return bin;
  }
}

// Использование
(async () => {
  try {
    const disasm = new SimpleDisassembler();
    await disasm.process(process.argv[2]);
    console.log('Disassembly complete');
  } catch (e) {
    console.error('Error:', e.message);
  }
})();
