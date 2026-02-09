package emu_c02

branch_if_flag :: proc(cpu: ^Cpu, addr: uint, flag: Status_Flag, set: bool) {
    if (set && flag in cpu.p) || (!set && flag not_in cpu.p) {
        cpu_tick(cpu, 1)
        cpu.pc = cast(u16)addr
    }
}

execute_instruction :: proc(cpu: ^Cpu, instruction: Instruction, addr: uint) {
    #partial switch(instruction) {
    case .adc:
        // TODO: deicmal maode
        assert(.Decimal not_in cpu.p)
        a := cast(u16)cpu.a
        m := cast(u16)bus_read(cpu.bus, addr)
        res := a + m
        if .Carry in cpu.p do res += 1
        cpu_set_flag(cpu, .Carry, res > 0xff)
        cpu_set_flag(cpu, .Overflow, ((a ~ m) & 0x80 == 0) && ((a ~ res) & 0x80 != 0))
        cpu.a = cast(u8)res
        cpu_set_nzflags(cpu, cpu.a)
    case .and:
        cpu.a &= bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.a)
    case .asl:
        m := bus_read(cpu.bus, addr)
        cpu_set_flag(cpu, .Carry, m & 0x80 != 0)
        m <<= 1
        bus_write(cpu.bus, addr, m)
        cpu_set_nzflags(cpu, m)
    case .asl_a:
        cpu_set_flag(cpu, .Carry, cpu.a & 0x80 != 0)
        cpu.a <<= 1
        cpu_set_nzflags(cpu, cpu.a)
    case .bit:
        m := bus_read(cpu.bus, addr)
        cpu_set_flag(cpu, .Zero, cpu.a & m == 0)
        cpu_set_flag(cpu, .Negative, m & 0x80 != 0)
        cpu_set_flag(cpu, .Overflow, m & 0x40 != 0)
    case .bcc:
        branch_if_flag(cpu, addr, .Carry, false)
    case .bcs:
        branch_if_flag(cpu, addr, .Carry, true)
    case .bmi:
        branch_if_flag(cpu, addr, .Negative, true)
    case .bpl:
        branch_if_flag(cpu, addr, .Negative, false)
    case .bvc:
        branch_if_flag(cpu, addr, .Overflow, false)
    case .bvs:
        branch_if_flag(cpu, addr, .Overflow, true)
    case .bra:
        cpu.pc = cast(u16)addr
    case .brl:
    case .bne:
        branch_if_flag(cpu, addr, .Zero, false)
    case .beq:
        branch_if_flag(cpu, addr, .Zero, true)
    case .brk:
        cpu.p += {.Break}
        // cpu_interrupt(cpu, .IRQ)
        cpu.running = false
    case .clc:
        cpu.p -= {.Carry}
    case .cld:
        cpu.p -= {.Decimal}
    case .cli:
        cpu.p -= {.Interrupt_Disable}
    case .clv:
        cpu.p -= {.Overflow}
    case .cmp:
        m := bus_read(cpu.bus, addr)
        result := cpu.a - m
        cpu_set_flag(cpu, .Carry, m <= cpu.a)
        cpu_set_nzflags(cpu, result)
    case .cop:
    case .cpx:
        m := bus_read(cpu.bus, addr)
        result := cpu.x - m
        cpu_set_flag(cpu, .Carry, m <= cpu.x)
        cpu_set_nzflags(cpu, result)
    case .cpy:
        m := bus_read(cpu.bus, addr)
        result := cpu.y - m
        cpu_set_flag(cpu, .Carry, m <= cpu.y)
        cpu_set_nzflags(cpu, result)
    case .dec:
        m := bus_read(cpu.bus, addr)
        m -= 1
        bus_write(cpu.bus, addr, m)
        cpu_set_nzflags(cpu, m)
    case .dec_a:
        cpu.a -= 1
        cpu_set_nzflags(cpu, cpu.a)
    case .dex:
        cpu.x -= 1
        cpu_set_nzflags(cpu, cpu.x)
    case .dey:
        cpu.y -= 1
        cpu_set_nzflags(cpu, cpu.y)
    case .eor:
        cpu.a ~= bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.a)
    case .inc:
        m := bus_read(cpu.bus, addr)
        m += 1
        bus_write(cpu.bus, addr, m)
        cpu_set_nzflags(cpu, m)
    case .inc_a:
        cpu.a += 1
        cpu_set_nzflags(cpu, cpu.a)
    case .inx:
        cpu.x += 1
        cpu_set_nzflags(cpu, cpu.x)
    case .iny:
        cpu.y += 1
        cpu_set_nzflags(cpu, cpu.y)
    case .jmp:
        cpu.pc = cast(u16)addr
    case .jml:
    case .jsr:
        cpu_push_byte(cpu, u8(cpu.pc >> 8))
        cpu_push_byte(cpu, u8(cpu.pc & 0xff))
        cpu.pc = cast(u16)addr
    case .lda:
        cpu.a = bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.a)
    case .ldx:
        cpu.x = bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.x)
    case .ldy:
        cpu.y = bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.y)
    case .lsr:
        m := bus_read(cpu.bus, addr)
        cpu_set_flag(cpu, .Carry, m & 1 != 0)
        m >>= 1
        bus_write(cpu.bus, addr, m)
        cpu_set_nzflags(cpu, m)
    case .lsr_a:
        cpu_set_flag(cpu, .Carry, cpu.a & 1 != 0)
        cpu.a >>= 1
        cpu_set_nzflags(cpu, cpu.a)
    case .mvn:
    case .mvp:
    case .nop:
        // Some NOPs cause a read
        // For now, I will only do a read if the address is 0
        // TODO: Have a separate NOP that does a read
        if addr != 0 do bus_read(cpu.bus, addr)
    case .ora:
        cpu.a |= bus_read(cpu.bus, addr)
        cpu_set_nzflags(cpu, cpu.a)
    case .pea:
    case .pei:
    case .per:
    case .pha:
        cpu_push_byte(cpu, cpu.a)
    case .phb:
    case .phd:
    case .phk:
    case .php:
        cpu_push_byte(cpu, transmute(u8)cpu.p)
    case .phx:
        cpu_push_byte(cpu, cpu.x)
    case .phy:
        cpu_push_byte(cpu, cpu.y)
    case .pla:
        cpu.a = cpu_pop_byte(cpu)
        cpu_set_nzflags(cpu, cpu.a)
    case .plb:
    case .pld:
    case .plp:
        cpu.p = transmute(bit_set[Status_Flag; u8])cpu_pop_byte(cpu)
    case .plx:
        cpu.x = cpu_pop_byte(cpu)
        cpu_set_nzflags(cpu, cpu.x)
    case .ply:
        cpu.y = cpu_pop_byte(cpu)
        cpu_set_nzflags(cpu, cpu.y)
    case .rep:
        // TODO:
    case .rol:
        m := bus_read(cpu.bus, addr)
        do_carry := m & 0x80 != 0
        m <<= 1
        if(.Carry in cpu.p) do m |= 1
        cpu_set_flag(cpu, .Carry, do_carry)
        cpu_set_nzflags(cpu, m)
        bus_write(cpu.bus, addr, m)
    case .rol_a:
        do_carry := cpu.a & 0x80 != 0
        cpu.a <<= 1
        if(.Carry in cpu.p) do cpu.a |= 1
        cpu_set_flag(cpu, .Carry, do_carry)
        cpu_set_nzflags(cpu, cpu.a)
    case .ror:
        m := bus_read(cpu.bus, addr)
        do_carry := m & 1 != 0
        m >>= 1
        if(.Carry in cpu.p) do m |= 0x80
        cpu_set_flag(cpu, .Carry, do_carry)
        cpu_set_nzflags(cpu, m)
        bus_write(cpu.bus, addr, m)
    case .ror_a:
        do_carry := cpu.a & 1 != 0
        cpu.a >>= 1
        if(.Carry in cpu.p) do cpu.a |= 0x80
        cpu_set_flag(cpu, .Carry, do_carry)
        cpu_set_nzflags(cpu, cpu.a)
    case .rti:
        cpu.p = transmute(bit_set[Status_Flag; u8])cpu_pop_byte(cpu)
        cpu.pc = cast(u16)cpu_pop_byte(cpu) | (cast(u16)cpu_pop_byte(cpu) << 8)
    case .rts:
        cpu.pc = cast(u16)cpu_pop_byte(cpu) | (cast(u16)cpu_pop_byte(cpu) << 8)
    case .rtl:
    case .sbc:
        // TODO: decimal mode
        assert(.Decimal not_in cpu.p)
        a := cast(u16)cpu.a
        m := cast(u16)bus_read(cpu.bus, addr)
        res := a + -m
        if .Carry not_in cpu.p do res -= 1
        // TODO: set overflow flag
        cpu_set_flag(cpu, .Carry, res >= 0xff)
        cpu.a = cast(u8)res
        cpu_set_nzflags(cpu, cpu.a)

    case .sec:
        cpu.p += {.Carry}
    case .sed:
        cpu.p += {.Decimal}
    case .sei:
        cpu.p += {.Interrupt_Disable}
    case .sep:
    case .stp:
    case .sta:
        bus_write(cpu.bus, addr, cpu.a)
    case .stx:
        bus_write(cpu.bus, addr, cpu.x)
    case .sty:
        bus_write(cpu.bus, addr, cpu.y)
    case .stz:
        bus_write(cpu.bus, addr, 0)
    case .tax:
        cpu.x = cpu.a
        cpu_set_nzflags(cpu, cpu.x)
    case .tay:
        cpu.y = cpu.a
        cpu_set_nzflags(cpu, cpu.y)
    case .txa:
        cpu.a = cpu.x
        cpu_set_nzflags(cpu, cpu.a)
    case .tsx:
        cpu.x = cpu.sp
        cpu_set_nzflags(cpu, cpu.x)
    case .txs:
        cpu.sp = cpu.x
        cpu_set_nzflags(cpu, cpu.sp)
    case .tya:
        cpu.a = cpu.y
        cpu_set_nzflags(cpu, cpu.a)
    case .txy:
        cpu.y = cpu.x
        cpu_set_nzflags(cpu, cpu.y)
    case .tyx:
        cpu.x = cpu.y
        cpu_set_nzflags(cpu, cpu.x)
    case .tcd:
    case .tdc:
    case .tcs:
    case .tsc:
    case .trb:
    case .tsb:
    case .wai:
    case .wdm:
    case .xba:
    case .xbe:
    case .xce:
    }
}

Instruction :: enum {
    adc,
    and,
    asl,
    asl_a,
    bit,
    bcc,
    bcs,
    bmi,
    bpl,
    bvc,
    bvs,
    bra,
    brl,
    bne,
    beq,
    brk,
    clc,
    cld,
    cli,
    clv,
    cmp,
    cop,
    cpx,
    cpy,
    dec,
    dec_a,
    dex,
    dey,
    eor,
    inc,
    inc_a,
    inx,
    iny,
    jmp,
    jml,
    jsr,
    lda,
    ldx,
    ldy,
    lsr,
    lsr_a,
    mvn,
    mvp,
    nop,
    ora,
    pea,
    pei,
    per,
    pha,
    phb,
    phd,
    phk,
    php,
    phx,
    phy,
    pla,
    plb,
    pld,
    plp,
    plx,
    ply,
    rep,
    rol,
    rol_a,
    ror,
    ror_a,
    rti,
    rts,
    rtl,
    sbc,
    sec,
    sed,
    sei,
    sep,
    stp,
    sta,
    stx,
    sty,
    stz,
    tax,
    tay,
    txa,
    tsx,
    txs,
    tya,
    txy,
    tyx,
    tcd,
    tdc,
    tcs,
    tsc,
    trb,
    tsb,
    wai,
    wdm,
    xba,
    xbe,
    xce,
};
