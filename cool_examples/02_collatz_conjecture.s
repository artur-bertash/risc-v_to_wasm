.global test_program
test_program:
    # collatz conjecture: count number of steps for n to reach 1.
    # start with n = 27 (takes exactly 111 steps to reach 1).
    addi t0, zero, 27    # n = 27
    addi t1, zero, 0     # steps = 0
    addi t2, zero, 1     # constant 1
    
    beq  t0, t2, end_collatz # check if n is already 1

collatz_loop:
    # compute both possibilities to avoid overlapping branch scopes
    srli t4, t0, 1       # next_even = n >> 1
    
    add  t5, t0, t0      # 2n
    add  t5, t5, t0      # 3n
    addi t5, t5, 1       # next_odd = 3n + 1
    
    andi t3, t0, 1       # is n odd? (t3 = 1 if odd, 0 if even)
    add  t0, zero, t4    # n = next_even (assume even)
    
    # if it was actually odd, override n with next_odd
    beq  t3, zero, skip_odd
    add  t0, zero, t5    # override: n = next_odd
skip_odd:
    
    addi t1, t1, 1       # steps++
    bne  t0, t2, collatz_loop # loop if n != 1
    
end_collatz:
    add  a0, zero, t1    # returns a
    ret
