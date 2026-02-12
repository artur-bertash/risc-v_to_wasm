.global test_program
test_program:
    li   s0, 0x1000      # buffer start address
    
    # <h1 style='color:#f06'>
    li t0, 60; sb t0, 0(s0)   # <
    li t0, 104; sb t0, 1(s0)  # h
    li t0, 49; sb t0, 2(s0)   # 1
    li t0, 32; sb t0, 3(s0)   # 
    li t0, 115; sb t0, 4(s0)  # s
    li t0, 116; sb t0, 5(s0)  # t
    li t0, 121; sb t0, 6(s0)  # y
    li t0, 108; sb t0, 7(s0)  # l
    li t0, 101; sb t0, 8(s0)  # e
    li t0, 61; sb t0, 9(s0)   # =
    li t0, 39; sb t0, 10(s0)  # '
    li t0, 99; sb t0, 11(s0)  # c
    li t0, 111; sb t0, 12(s0) # o
    li t0, 108; sb t0, 13(s0) # l
    li t0, 111; sb t0, 14(s0) # o
    li t0, 114; sb t0, 15(s0) # r
    li t0, 58; sb t0, 16(s0)  # :
    li t0, 35; sb t0, 17(s0)  # #
    li t0, 102; sb t0, 18(s0) # f
    li t0, 48; sb t0, 19(s0)  # 0
    li t0, 54; sb t0, 20(s0)  # 6
    li t0, 39; sb t0, 21(s0)  # '
    li t0, 62; sb t0, 22(s0)  # >
    
    addi s1, s0, 23


    li   t0, 94; sb t0, 0(s1)  # ^
    li   t0, 95; sb t0, 1(s1)  # _
    li   t0, 94; sb t0, 2(s1)  # ^
    addi s1, s1, 3
    
    # </h1>
    li t0, 60; sb t0, 0(s1)
    li t0, 47; sb t0, 1(s1)
    li t0, 104; sb t0, 2(s1)
    li t0, 49; sb t0, 3(s1)
    li t0, 62; sb t0, 4(s1)
    sb zero, 5(s1)
    
    add  a0, zero, s0
    ret

