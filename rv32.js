// Browser pipeline: user asm + wasm.s --(GNU as, prebuilt wasm)--> RV32 code
// --(tiny emulator runs the RISC-V translator)--> .wasm bytes

const OUT = 0x20000, MEM = 0x40000;

// Entry stub: call the translator with (code, output buffer), then ecall to halt.
// .data/.bss become subsection `.text 1` so everything lands in one section
// and gas resolves every la/call/branch itself (no linker needed).
function combine(user, translator) {
  const src = `.text\n la a0, test_program\n li a1, ${OUT}\n call rv32_emit_wasm\n ecall\n`
    + translator + "\n.text\n" + user + "\n";
  return src.replace(/^\s*\.(data|bss)\b/gm, ".text 1");
}

export async function assemble(src, gasLoader) {
  const gas = await gasLoader("riscv32-linux-gnu");
  const errs = [];
  let obj;
  await gas({
    print: (s) => errs.push(s), printErr: (s) => errs.push(s),
    arguments: ["-march=rv32i", "-mabi=ilp32", "-mno-relax", "-o", "a.o", "a.s"],
    preRun: [(m) => m.FS.writeFile("a.s", src)],
    postRun: [(m) => { try { obj = m.FS.readFile("a.o"); } catch {} }],
  });
  if (!obj) throw new Error(errs.join("\n") || "assembly failed");
  return obj;
}

// Minimal linker: take .text out of the ELF32 object (loaded at address 0)
// and patch the pc-relative relocations gas leaves for la / call.
export function link(elf) {
  const v = new DataView(elf.buffer, elf.byteOffset, elf.byteLength);
  const shoff = v.getUint32(0x20, true), n = v.getUint16(0x30, true);
  const sh = (i, f) => v.getUint32(shoff + i * 40 + f, true);
  const str = (p) => { let s = ""; while (elf[p]) s += String.fromCharCode(elf[p++]); return s; };
  const names = [...Array(n)].map((_, i) => str(sh(v.getUint16(0x32, true), 16) + sh(i, 0)));
  const find = (nm) => names.indexOf(nm);
  const ti = find(".text");
  const code = elf.slice(sh(ti, 16), sh(ti, 16) + sh(ti, 20)), c = new DataView(code.buffer);
  const ri = find(".rela.text");
  if (ri < 0) return code;

  const sym = find(".symtab"), symStr = sh(find(".strtab"), 16);
  const symAt = (k) => {
    const o = sh(sym, 16) + k * 16;
    if (v.getUint16(o + 14, true) !== ti) throw new Error(`undefined symbol: ${str(symStr + v.getUint32(o, true))}`);
    return v.getUint32(o + 4, true);
  };
  const patch = (p, mask, bits) => c.setUint32(p, (c.getUint32(p, true) & mask) | bits, true);
  const hi = (off) => ((off + 0x800) >>> 12) << 12, lo = (off) => off & 0xfff;
  const relocs = [];
  for (let r = sh(ri, 16); r < sh(ri, 16) + sh(ri, 20); r += 12) {
    const info = v.getUint32(r + 4, true);
    relocs.push({ p: v.getUint32(r, true), type: info & 0xff, s: symAt(info >>> 8) + v.getInt32(r + 8, true) });
  }
  const hiOff = {};
  for (const { p, type, s } of relocs) {
    const off = s - p;
    if (type === 23) { hiOff[p] = off; patch(p, 0xfff, hi(off)); }               // PCREL_HI20 (auipc)
    else if (type === 18 || type === 19) {                                         // CALL: auipc + jalr
      patch(p, 0xfff, hi(off)); patch(p + 4, 0xfffff, lo(off) << 20);
    } else if (![16, 17, 24, 25, 51].includes(type)) throw new Error(`unsupported relocation ${type}`);
  }
  for (const { p, type, s } of relocs) {                                           // LO12 points at its auipc
    if (type === 24) patch(p, 0xfffff, lo(hiOff[s]) << 20);
    if (type === 25) patch(p, 0x1fff07f, ((lo(hiOff[s]) >> 5) << 25) | ((hiOff[s] & 31) << 7));
  }
  return code;
}

// Minimal RV32I interpreter: runs from address 0 until ecall, returns memory + a0.
export function run(code, maxSteps = 5e7) {
  const m = new Uint8Array(MEM), v = new DataView(m.buffer), x = new Int32Array(32);
  m.set(code); x[2] = MEM;
  let pc = 0;
  for (let n = 0; n < maxSteps; n++) {
    const i = v.getUint32(pc, true), op = i & 0x7f, rd = (i >> 7) & 31, f3 = (i >> 12) & 7;
    const a = x[(i >> 15) & 31], b = x[(i >> 20) & 31], immI = i >> 20;
    const immS = ((i >> 25) << 5) | ((i >> 7) & 31);
    const immB = ((i >> 31) << 12) | (((i >> 7) & 1) << 11) | (((i >> 25) & 63) << 5) | (((i >> 8) & 15) << 1);
    let next = pc + 4, r;
    switch (op) {
      case 0x37: r = i & 0xfffff000; break;                                     // lui
      case 0x17: r = pc + (i & 0xfffff000); break;                              // auipc
      case 0x6f: r = next; next = pc + ((((i >> 31) << 20) | (i & 0xff000) | (((i >> 20) & 1) << 11) | (((i >> 21) & 0x3ff) << 1))); break; // jal
      case 0x67: r = next; next = (a + immI) & ~1; break;                       // jalr
      case 0x63: if ([a === b, a !== b, , , a < b, a >= b, a >>> 0 < b >>> 0, a >>> 0 >= b >>> 0][f3]) next = pc + immB; break;
      case 0x03: { const p = a + immI; r = [v.getInt8(p), v.getInt16(p, true), v.getInt32(p, true), , v.getUint8(p), v.getUint16(p, true)][f3]; break; }
      case 0x23: { const p = a + immS; [() => v.setUint8(p, b), () => v.setUint16(p, b, true), () => v.setUint32(p, b, true)][f3](); break; }
      case 0x13: case 0x33: {
        const y = op === 0x13 ? immI : b, alt = (i >> 30) & 1;
        r = [op === 0x33 && alt ? a - y : a + y, a << y, a < y | 0, a >>> 0 < y >>> 0 | 0, a ^ y, alt ? a >> y : a >>> y, a | y, a & y][f3];
        break;
      }
      case 0x73: return { mem: m, a0: x[10] };                                   // ecall = halt
      default: throw new Error(`bad instruction ${i.toString(16)} at ${pc}`);
    }
    if (r !== undefined && rd) x[rd] = r;
    pc = next >>> 0;
  }
  throw new Error("step limit hit (missing ret?)");
}

export async function compile(user, translator, gasLoader) {
  const { mem, a0 } = run(link(await assemble(combine(user, translator), gasLoader)));
  return mem.slice(OUT, OUT + a0);
}
