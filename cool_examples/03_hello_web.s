.global test_program
test_program:
    li   s0, 0x1000      # buffer start address

    # write "<h2>risc-v!</h2>" directly to memory byte-by-byte
    
    li   t0, 60          # '<'
    sb   t0, 0(s0)
    li   t0, 104         # 'h'
    sb   t0, 1(s0)
    li   t0, 50          # '2'
    sb   t0, 2(s0)
    li   t0, 62          # '>'
    sb   t0, 3(s0)
    
    li   t0, 82          # 'r'
    sb   t0, 4(s0)
    li   t0, 73          # 'i'
    sb   t0, 5(s0)
    li   t0, 83          # 's'
    sb   t0, 6(s0)
    li   t0, 67          # 'c'
    sb   t0, 7(s0)
    li   t0, 45          # '-'
    sb   t0, 8(s0)
    li   t0, 86          # 'v'
    sb   t0, 9(s0)
    li   t0, 33          # '!'
    sb   t0, 10(s0)
    
    li   t0, 60          # '<'
    sb   t0, 11(s0)
    li   t0, 47          # '/'
    sb   t0, 12(s0)
    li   t0, 104         # 'h'
    sb   t0, 13(s0)
    li   t0, 50          # '2'
    sb   t0, 14(s0)
    li   t0, 62          # '>'
    sb   t0, 15(s0)
    
    sb   zero, 16(s0)    # null terminator

    add  a0, zero, s0    # returns a
    ret
