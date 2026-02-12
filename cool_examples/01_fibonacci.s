.global test_program
test_program:
    # compute 12th fibonacci number
    # f(0)=0, f(1)=1, f(2)=1, f(3)=2, f(4)=3, f(5)=5, ... f(12)=144
    
    addi t0, zero, 12    # n = 12 (loop counter)
    addi t1, zero, 0     # a = 0
    addi t2, zero, 1     # b = 1

    beq  t0, zero, end_fib  # if n == 0, break

fib_loop:
    add  t3, t1, t2      # t3 = a + b
    add  t1, zero, t2    # a = b
    add  t2, zero, t3    # b = next_fib

    addi t0, t0, -1      # n--
    bne  t0, zero, fib_loop # if n != 0, jump to start of loop

end_fib:
    add  a0, zero, t1    # returns a
    ret
