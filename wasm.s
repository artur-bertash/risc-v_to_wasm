# minimalist risc-v to wasm translator
# supported opcodes are addi add andi srli lb sb beq bne lui ret
# 1 to 1 register mapping xN to local N
# 2 byte leb128 logic fixed sizes for immediates and sections

.data
wasm_header:
    .byte 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00
    .byte 0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f
    .byte 0x03, 0x02, 0x01, 0x00
    .byte 0x05, 0x03, 0x01, 0x00, 0x01
    .byte 0x07, 0x11, 0x02, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x00
    .byte 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02, 0x00
    .byte 0x0a # code section id
header_end:

jump_targets: .space 1040
jump_dir:     .space 256

.global rv32_emit_wasm
.text

rv32_emit_wasm:
    addi sp, sp, -24
    sw   ra, 0(sp)
    sw   s0, 4(sp)
    sw   s1, 8(sp)
    sw   s2, 12(sp)
    sw   s3, 16(sp)
    sw   s7, 20(sp)

    mv   s0, a0         # s0 is rv32 pc
    mv   s1, a1         # s1 is wasm write ptr
    mv   s3, s1         # s3 is start ptr

    # copy manual header
    la   t0, wasm_header
    la   t1, header_end
copy_hdr:
    lb   t2, 0(t0)
    sb   t2, 0(s1)
    addi t0, t0, 1
    addi s1, s1, 1
    blt  t0, t1, copy_hdr

    # code section size placeholder 2 bytes
    mv   s7, s1
    addi s1, s1, 2

    # 1 function
    li   t0, 1
    sb   t0, 0(s1)
    addi s1, s1, 1

    # func body size placeholder 2 bytes
    mv   s2, s1
    addi s1, s1, 2

    # local decls 1 group 32 locals of i32 0x7f
    li   t0, 1
    sb   t0, 0(s1)
    li   t0, 32
    sb   t0, 1(s1)
    li   t0, 0x7f
    sb   t0, 2(s1)
    addi s1, s1, 3

    # scan jump targets
    mv   a0, s0
    jal  ra, scan_jump_offsets

translate_loop:
    lw   t1, 0(s0)

    # ret is 0x00008067
    li   t0, 0x00008067
    beq  t1, t0, end_translation

    # emit block ends for forward jumps
    mv   a0, s0
    li   a1, 1
    jal  ra, count_targets_at
    beqz a0, check_bwd
fwd_close:
    li   t0, 0x0B
    sb   t0, 0(s1)
    addi s1, s1, 1
    addi a0, a0, -1
    bnez a0, fwd_close
check_bwd:
    # emit loop opens for backward jumps
    mv   a0, s0
    li   a1, 0
    jal  ra, count_targets_at
    beqz a0, dispatch
bwd_open:
    li   t0, 0x03
    sb   t0, 0(s1)
    li   t0, 0x40
    sb   t0, 1(s1)
    addi s1, s1, 2
    addi a0, a0, -1
    bnez a0, bwd_open

dispatch:
    # extract opcode rd rs1 rs2
    andi t2, t1, 0x7F
    srli a2, t1, 7
    andi a2, a2, 0x1F
    srli a3, t1, 15
    andi a3, a3, 0x1F
    srli a4, t1, 20
    andi a4, a4, 0x1F

    li   t0, 0x13
    beq  t2, t0, op_itype
    li   t0, 0x33
    beq  t2, t0, op_rtype
    li   t0, 0x03
    beq  t2, t0, op_load
    li   t0, 0x63
    beq  t2, t0, op_branch
    li   t0, 0x23
    beq  t2, t0, op_store
    li   t0, 0x37
    beq  t2, t0, op_lui

advance_pc:
    addi s0, s0, 4
    j    translate_loop

# handlers
op_itype:
    srli t3, t1, 20         # imm
    slli t3, t3, 20
    srai t3, t3, 20         # sign extend 12 bit immediate
    jal  ra, get_rs1
    srli t4, t1, 12
    andi t4, t4, 0x7        # funct3
    li   t2, 0x6A           # addi
    beqz t4, itype_emit
    li   t2, 0x71           # andi
    li   t5, 7
    beq  t4, t5, itype_emit
    li   t2, 0x76           # srli
    andi t3, t3, 0x1F       # shamt
itype_emit:
    jal  ra, push_imm
    sb   t2, 0(s1)
    addi s1, s1, 1
    jal  ra, set_rd
    j    advance_pc

op_rtype:
    jal  ra, get_rs1
    jal  ra, get_rs2
    li   t2, 0x6A           # add
    sb   t2, 0(s1)
    addi s1, s1, 1
    jal  ra, set_rd
    j    advance_pc

op_branch:
    jal  ra, decode_b_imm   # t3 is signed imm
    bltz t3, br_push_args
    li   t4, 0x02           # block
    sb   t4, 0(s1)
    li   t4, 0x40
    sb   t4, 1(s1)
    addi s1, s1, 2
br_push_args:
    jal  ra, get_rs1
    jal  ra, get_rs2
    li   t2, 0x46           # eq
    srli t4, t1, 12
    andi t4, t4, 0x7
    beqz t4, br_emit
    li   t2, 0x47           # ne
br_emit:
    sb   t2, 0(s1)          # eq or ne
    li   t2, 0x0D           # br_if
    sb   t2, 1(s1)
    sb   zero, 2(s1)
    addi s1, s1, 3
    bltz t3, br_loop_end
    j    advance_pc
br_loop_end:
    li   t2, 0x0B           # end
    sb   t2, 0(s1)
    addi s1, s1, 1
    j    advance_pc

op_load:
    srli t3, t1, 20         # imm
    slli t3, t3, 20
    srai t3, t3, 20         # sign extend 12 bit immediate
    jal  ra, get_rs1
    jal  ra, push_imm
    li   t2, 0x6A           # add
    sb   t2, 0(s1)
    addi s1, s1, 1
    li   t2, 0x2C           # load8_s
    sb   t2, 0(s1)
    sb   zero, 1(s1)
    sb   zero, 2(s1)
    addi s1, s1, 3
    jal  ra, set_rd
    j    advance_pc

op_store:
    jal  ra, get_rs1
    jal  ra, decode_s_imm
    jal  ra, push_imm
    li   t2, 0x6A           # add
    sb   t2, 0(s1)
    addi s1, s1, 1
    jal  ra, get_rs2
    li   t2, 0x3A           # store8
    sb   t2, 0(s1)
    sb   zero, 1(s1)
    sb   zero, 2(s1)
    addi s1, s1, 3
    j    advance_pc

op_lui:
    li   t0, 0xFFFFF000
    and  t3, t1, t0         # imm
    jal  ra, push_imm
    jal  ra, set_rd
    j    advance_pc

# helpers
get_rs1:
    li   t0, 0x20
    sb   t0, 0(s1)
    sb   a3, 1(s1)
    addi s1, s1, 2
    ret
get_rs2:
    li   t0, 0x20
    sb   t0, 0(s1)
    sb   a4, 1(s1)
    addi s1, s1, 2
    ret
set_rd:
    beqz a2, set_rd_skip
    li   t0, 0x21
    sb   t0, 0(s1)
    sb   a2, 1(s1)
    addi s1, s1, 2
set_rd_skip:
    ret

push_imm:
    # 2 byte leb128 of t3
    li   t0, 0x41
    sb   t0, 0(s1)
    addi s1, s1, 1
    andi t0, t3, 0x7F
    ori  t0, t0, 0x80
    sb   t0, 0(s1)
    srai t3, t3, 7
    andi t3, t3, 0x7F
    sb   t3, 1(s1)
    addi s1, s1, 2
    ret

decode_b_imm:
    li   t3, 0
    andi t4, t1, 0x80
    slli t4, t4, 4
    or   t3, t3, t4
    li   t4, 0xF00
    and  t4, t1, t4
    srli t4, t4, 7
    or   t3, t3, t4
    li   t4, 0x7E000000
    and  t4, t1, t4
    srli t4, t4, 20
    or   t3, t3, t4
    li   t4, 0x80000000
    and  t4, t1, t4
    srli t4, t4, 19
    or   t3, t3, t4
    slli t3, t3, 19
    srai t3, t3, 19
    ret

decode_s_imm:
    li   t3, 0
    li   t4, 0xFE000000
    and  t4, t1, t4
    srli t4, t4, 20
    or   t3, t3, t4
    li   t4, 0xF80
    and  t4, t1, t4
    srli t4, t4, 7
    or   t3, t3, t4
    slli t3, t3, 20
    srai t3, t3, 20
    ret

end_translation:
    # return local 10 which is a0
    li   t0, 0x20
    sb   t0, 0(s1)
    li   t0, 10
    sb   t0, 1(s1)
    li   t0, 0x0F
    sb   t0, 2(s1)
    li   t0, 0x0B
    sb   t0, 3(s1)
    addi s1, s1, 4

    # backpatch 2 byte leb128 at s2 and s7
    # body size
    sub  t0, s1, s2
    addi t0, t0, -2
    andi t2, t0, 0x7F
    ori  t2, t2, 0x80
    sb   t2, 0(s2)
    srai t0, t0, 7
    andi t0, t0, 0x7F
    sb   t0, 1(s2)

    # section size
    sub  t0, s1, s7
    addi t0, t0, -2
    andi t2, t0, 0x7F
    ori  t2, t2, 0x80
    sb   t2, 0(s7)
    srai t0, t0, 7
    andi t0, t0, 0x7F
    sb   t0, 1(s7)

    sub  a0, s1, s3
    lw   ra, 0(sp)
    lw   s0, 4(sp)
    lw   s1, 8(sp)
    lw   s2, 12(sp)
    lw   s3, 16(sp)
    lw   s7, 20(sp)
    addi sp, sp, 24
    ret

# scan jumps
scan_jump_offsets:
    la   t0, jump_targets
    sw   zero, 0(t0)
    mv   t5, a0
sjo_loop:
    lw   t1, 0(t5)
    li   t2, 0x00008067
    beq  t1, t2, sjo_done
    andi t2, t1, 0x7F
    li   t3, 0x63
    bne  t2, t3, sjo_next
    addi sp, sp, -4
    sw   ra, 0(sp)
    jal  ra, decode_b_imm
    lw   ra, 0(sp)
    addi sp, sp, 4
    add  t3, t5, t3
    li   t4, 1
    bge  t3, t5, sjo_store
    li   t4, 0
sjo_store:
    lw   t2, 0(t0)
    slli a1, t2, 2
    addi a1, a1, 4
    add  a1, a1, t0
    sw   t3, 0(a1)
    la   a1, jump_dir
    add  a1, a1, t2
    sb   t4, 0(a1)
    addi t2, t2, 1
    sw   t2, 0(t0)
sjo_next:
    addi t5, t5, 4
    j    sjo_loop
sjo_done:
    ret

count_targets_at:
    la   t0, jump_targets
    lw   t2, 0(t0)
    la   t3, jump_dir
    li   t4, 0
    li   a2, 0
cta_loop:
    bge  t4, t2, cta_done
    slli t5, t4, 2
    addi t5, t5, 4
    add  t5, t5, t0
    lw   t6, 0(t5)
    bne  t6, a0, cta_next
    add  t5, t3, t4
    lb   t6, 0(t5)
    bne  t6, a1, cta_next
    addi a2, a2, 1
cta_next:
    addi t4, t4, 1
    j    cta_loop
cta_done:
    mv   a0, a2
    ret
