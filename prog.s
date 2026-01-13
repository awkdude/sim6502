    .code
    clc
    lda #$02
loop:
    cmp #0
    beq done
    jsr foo
    bra loop
foo:
    asl a
    rts
done:
    brk

    .segment "VECTORS"
    .addr $0000, $8000, $0000
