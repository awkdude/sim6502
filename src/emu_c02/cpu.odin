package emu_c02

import "core:fmt"

VECTOR_RESET :: 0xfffc

Status_Flag :: enum {
    Carry,
    Zero,
    Interrupt_Disable,
    Decimal,
    Break,
    Unused,
    Overflow,
    Negative,
}

Address_Mode :: enum {
    imp,
    acc,  // ins a
    imm,  // #$00
    sre,  // $00,s
    dpg,  // $00
    dpx,  // $00,x
    dpy,  // $00,y
    idp,  // ($00)
    idx,  // ($00,x)
    idy,  // ($00),y
    idl,  // [$00]
    idly, // [$00],y
    isy,  // ($00,s),y
    abs,  // $0000 
    abx,  // $0000,x
    aby,  // $0000,y
    abl,  // $000000
    alx,  // $000000,x
    ind,  // ($0000)
    iax,  // ($0000,x)
    ial,  // [$000000]
    rel,  // $0000
    rll,  // $0000
    bmv,  // $00,$00
}

Cpu :: struct {
    using reg: struct {
        a, x, y, sp: u8,
        p: bit_set[Status_Flag; u8],
        pc: u16,
    },
    clock_cycles: uint,
    bus: ^Bus,
    running: bool,
}

cpu_init :: proc(cpu: ^Cpu, bus: ^Bus) {
    cpu.a = 0
    cpu.x = 0
    cpu.y = 0
    cpu.sp = 0xff
    cpu.p = {.Negative, .Zero}
    cpu.pc = 0
    cpu.clock_cycles = 0
    cpu.bus = bus
    cpu.running = true

    cpu.pc = bus_read16(cpu.bus, VECTOR_RESET)
}

cpu_tick :: proc(cpu: ^Cpu, cc: uint) {
    // TODO:
    cpu.clock_cycles += cc
}

cpu_push_byte :: proc(cpu: ^Cpu, byte: u8) {
    ea := 0x100 | cast(uint)cpu.sp
    bus_write(cpu.bus, ea, byte)
    cpu.sp -= 1
}

cpu_pop_byte :: proc(cpu: ^Cpu) -> u8 {
    cpu.sp += 1
    ea := 0x100 | cast(uint)cpu.sp
    return bus_read(cpu.bus, ea)
}

@(private="file")
cpu_advance_byte :: proc(cpu: ^Cpu) -> u8 {
    byte := bus_read(cpu.bus, cast(uint)cpu.pc)
    cpu.pc += 1
    return byte
}

@(private="file")
cpu_advance_2bytes :: proc(cpu: ^Cpu) -> u16 {
    dbl_byte := bus_read16(cpu.bus, cast(uint)cpu.pc)
    cpu.pc += 2
    return dbl_byte
}

@(private="file")
address_from_mode :: proc(cpu: ^Cpu, mode: Address_Mode) -> uint {
    ea: u16 = 0
    #partial switch(mode) {
    case .imm:
        ea = cpu.pc
        cpu.pc += 1
    case .rel:
        offset := cast(u16)cpu_advance_byte(cpu)
        if offset & 0x80 != 0 do offset |= 0xff00;
        ea = cpu.pc + offset
    case .dpg: ea = cast(u16)cpu_advance_byte(cpu)
    case .dpx: ea = cast(u16)(cpu_advance_byte(cpu) + cpu.x)
    case .dpy: ea = cast(u16)(cpu_advance_byte(cpu) + cpu.y)
    case .abs: ea = cpu_advance_2bytes(cpu)
    }
    return cast(uint)ea
}

cpu_set_nzflags :: proc(cpu: ^Cpu, value: u8) {
    if value & 0x80 != 0 {
        cpu.p += {.Negative}
    } else {
        cpu.p -= {.Negative}
    }
    if value == 0 {
        cpu.p += {.Zero}
    } else {
        cpu.p -= {.Zero}
    }
}

cpu_step :: proc(cpu: ^Cpu) {
    opcode_byte := cpu_advance_byte(cpu)
    opcode := opcode_table_c02[opcode_byte]
    execute_instruction(cpu, opcode.instruction, address_from_mode(cpu, opcode.address_mode))
    cpu_tick(cpu, opcode.clock_cycles)
}

cpu_set_flag :: proc(cpu: ^Cpu, flag: Status_Flag, cond: bool) {
    if cond {
        cpu.p += {flag}
    } else {
        cpu.p -= {flag}
    }
}


cpu_debug :: proc(cpu: ^Cpu) {
    n := 'n' if .Negative in cpu.p else '_'
    v := 'v' if .Overflow in cpu.p else '_'
    b := 'b' if .Break in cpu.p else '_'
    d := 'd' if .Decimal in cpu.p else '_'
    i := 'i' if .Interrupt_Disable in cpu.p else '_'
    z := 'z' if .Zero in cpu.p else '_'
    c := 'c' if .Carry in cpu.p else '_'
    buf: [128]u8
    str := fmt.bprintf(
        buf[:],
        "A: %2.0x, X: %2.0x, Y: %2.0x, SP: 01%2.0x, PC: %4.0x, P: %c%c%c%c%c%c%c (%v cc)\n", 
        cpu.a,
        cpu.x,
        cpu.y,
        cpu.sp,
        cpu.pc,
        n,
        v,
        b,
        d,
        i,
        z,
        c,
        cpu.clock_cycles,
    )
    fmt.println(str)
}

