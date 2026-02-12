#!/bin/bash

riscv64-linux-gnu-gcc -march=rv32i -mabi=ilp32 -nostdlib -static input.s _start.s wasm.s -o translator

qemu-riscv32 translator > out.wasm

INPUT_CODE=$(cat input.s | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
WASM_BASE64=$(base64 -w 0 out.wasm)

cat << EOF > run.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>RISC-V to WASM</title>
  <style>
    body { font-family: monospace; background: #ffffff; color: #333333; display: flex; flex-direction: column; align-items: center; padding: 20px; }
    body > h1 { color: #000000; font-size: 18px; margin-bottom: 20px; }
    .container { display: flex; gap: 20px; width: 100%; max-width: 1000px; justify-content: center; align-items: stretch; height: 80vh; }
    .box { border: 1px solid #cccccc; padding: 15px; background: #f5f5f5; display: flex; flex-direction: column; }
    .code-box { flex: 2; }
    .output-container { flex: 1.5; display: flex; flex-direction: column; gap: 20px; }
    .result-box { flex: 1; text-align: center; }
    .wasm-box { flex: 2; text-align: left; overflow: hidden; }
    .box > h2 { font-size: 12px; text-transform: uppercase; color: #666666; margin-top: 0; border-bottom: 1px solid #dddddd; padding-bottom: 5px; margin-bottom: 15px; width: 100%; text-align: left; }
    pre { margin: 0; font-size: 13px; color: #333333; white-space: pre-wrap; word-wrap: break-word; text-align: left; }
    #output { font-size: 48px; font-weight: bold; color: #000000; flex-grow: 1; display: flex; align-items: center; justify-content: center; margin: 0; }
    #wasm-binary { font-size: 11px; font-family: 'Courier New', monospace; color: #444; overflow-y: auto; flex-grow: 1; line-height: 1.4; }
  </style>
</head>
<body>
  <h1>RISC-V to WASM Translator</h1>
  
  <div class="container">
    <div class="box code-box">
      <h2>RISC-V Source (input.s)</h2>
      <pre style="overflow-y: auto; flex-grow: 1;">${INPUT_CODE}</pre>
    </div>
    
    <div class="output-container">
      <div class="box result-box">
        <h2>WASM Output</h2>
        <div id="output">...</div>
      </div>
      
      <div class="box wasm-box">
        <h2>WASM Code (Hex)</h2>
        <pre id="wasm-binary"></pre>
      </div>
    </div>
  </div>

  <script>
    const wasmBase64 = "${WASM_BASE64}";
    const binaryString = atob(wasmBase64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    Promise.resolve(bytes.buffer)
      .then(bytes => {
        const view = new Uint8Array(bytes);
        let hex = "";
        for (let i = 0; i < view.length; i++) {
          hex += view[i].toString(16).padStart(2, '0').toUpperCase() + " ";
          if ((i + 1) % 8 === 0) hex += " ";
          if ((i + 1) % 16 === 0) hex += "\n";
        }
        document.getElementById('wasm-binary').textContent = hex;
        return WebAssembly.instantiate(bytes);
      })
      .then(obj => {
        const result = obj.instance.exports.main();
        const out = document.getElementById('output');
        
        const mem = new Uint8Array(obj.instance.exports.memory.buffer);
        let str = "";
        let i = result;
        while (mem[i] !== 0) {
          str += String.fromCharCode(mem[i]);
          i++;
        }
        out.innerHTML = str;
      });
  </script>
</body>
</html>
EOF
