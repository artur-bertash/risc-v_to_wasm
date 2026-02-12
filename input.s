.global test_program
test_program:
    li t0, 0x1000
    li t1, 42
    sb t1, 0(t0)
    lb a0, 0(t0)
    ret
