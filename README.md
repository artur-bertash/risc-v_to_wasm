# RISC-V to WASM turing-complete micro-compiler (transpiler), written entirely in pure RISC-V assembly. 


<img width="1013" height="773" alt="image" src="https://github.com/user-attachments/assets/f729c296-a502-4c4e-8b3d-5d88a4a9a3cf" />


# Prereq
```bash
sudo apt install gcc-riscv64-linux-gnu
sudo apt install qemu-user
```
# Architecture
- Fully self-contained binary that emits one WASM module and enocdes numbers using a simplified 2-byte LEB128 format
- Turing complete. Instructions implemented: add, addi, andi, srli, lb, sb, beq, bne, lui, ret
- Peforms a two pass of RISC-V code to emulate strict structure required for branches in WebAssembly

