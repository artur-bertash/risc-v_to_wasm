.bss
output_buf:  .space  8192

.text
.global _start
.extern test_program

_start:
    la   a0, test_program
    la   a1, output_buf
    call rv32_emit_wasm
    
    mv   a2, a0       # a2 = byte count returned by rv32_emit_wasm
    la   a1, output_buf
    li   a0, 1        # stdout
    li   a7, 64       # sys_write
    ecall
    
    li   a0, 0        # exit code 0
    li   a7, 93       # sys_exit
    ecall
