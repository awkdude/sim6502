package emu_c02

import "core:fmt"
import "core:strings"

Disassembler :: struct {
    memory: []u8,
    position: uint,
    show_address: bool,
    builder: strings.Builder,
}

disassembler_init :: proc(disasm: ^Disassembler, memory: []u8, start_position: uint) {
    disasm.memory = memory
    disasm.position = start_position
    disasm.show_address = true
    strings.builder_init(&disasm.builder, 0, 32)
}

@(private="file")
advance_byte :: proc(disasm: ^Disassembler) -> u8 {
    m := disasm.memory[disasm.position]
    disasm.position += 1
    return m
}

@(private="file")
advance_2bytes :: proc(disasm: ^Disassembler) -> u16 {
    m := cast(u16)disasm.memory[disasm.position] | cast(u16)disasm.memory[disasm.position+1] << 8
    disasm.position += 2
    return m
}

@(private="file")
advance_3bytes :: proc(disasm: ^Disassembler) -> u32 {
    m := cast(u32)disasm.memory[disasm.position] | 
        (cast(u32)disasm.memory[disasm.position+1] << 8) |
        (cast(u32)disasm.memory[disasm.position+2] << 16)
    disasm.position += 3
    return m
}

disassemble_next_at :: proc(disasm: ^Disassembler, offset: uint) -> (string, bool) {
    disasm.position = offset
    if disasm.position >= len(disasm.memory) do return "", false
    // Could have used a string builder instead
    strings.builder_reset(&disasm.builder)
    if disasm.show_address {
        fmt.sbprintf(&disasm.builder, "$%4.0x: ", disasm.position)
    }
    opcode := opcode_table_c02[advance_byte(disasm)]
    fmt.sbprint(&disasm.builder, get_mnemonic(opcode.instruction))
    #partial switch(opcode.address_mode) {
    case .imp:
    case .acc: 
        fmt.sbprint(&disasm.builder, " a")
    case .imm:
        fmt.sbprintf(&disasm.builder, " #$%2.0x", advance_byte(disasm))
    case .dpg, .rel:
        fmt.sbprintf(&disasm.builder, " $%2.0x", advance_byte(disasm))
    case .dpx:
        fmt.sbprintf(&disasm.builder, " $%2.0x,X", advance_byte(disasm))
    case .dpy:
        fmt.sbprintf(&disasm.builder, " $%2.0x,Y", advance_byte(disasm))
    case .idp:
        fmt.sbprintf(&disasm.builder, " ($%2.0x)", advance_byte(disasm))
    case .idx:
        fmt.sbprintf(&disasm.builder, " ($%2.0x,X)", advance_byte(disasm))
    case .idy:
        fmt.sbprintf(&disasm.builder, " ($%2.0x),Y", advance_byte(disasm))
    case .abs:
        fmt.sbprintf(&disasm.builder, " $%4.0x", advance_2bytes(disasm))
    case .abx:
        fmt.sbprintf(&disasm.builder, " $%4.0x,X", advance_2bytes(disasm))
    case .aby:
        fmt.sbprintf(&disasm.builder, " $%4.0x,Y", advance_2bytes(disasm))
    case .ind:
        fmt.sbprintf(&disasm.builder, " ($%4.0x)", advance_2bytes(disasm))
    case:
        fmt.sbprint(&disasm.builder, " ???")
    }

    return strings.to_string(disasm.builder), true
}

@(private="file")
get_mnemonic :: proc(instruction: Instruction) -> string {
    name := "???"
    switch(instruction) {
    case .adc: name = "adc"
    case .and: name = "and"
    case .asl, .asl_a: name = "asl"
    case .bit: name = "bit"
    case .bcc: name = "bcc"
    case .bcs: name = "bcs"
    case .bmi: name = "bmi"
    case .bpl: name = "bpl"
    case .bvc: name = "bvc"
    case .bvs: name = "bvs"
    case .bra: name = "bra"
    case .brl: name = "brl"
    case .bne: name = "bne"
    case .beq: name = "beq"
    case .brk: name = "brk"
    case .clc: name = "clc"
    case .cld: name = "cld"
    case .cli: name = "cli"
    case .clv: name = "clv"
    case .cmp: name = "cmp"
    case .cop: name = "cop"
    case .cpx: name = "cpx"
    case .cpy: name = "cpy"
    case .dec, .dec_a: name = "dec"
    case .dex: name = "dex"
    case .dey: name = "dey"
    case .eor: name = "eor"
    case .inc, .inc_a: name = "inc"
    case .inx: name = "inx"
    case .iny: name = "iny"
    case .jmp: name = "jmp"
    case .jml: name = "jml"
    case .jsr: name = "jsr"
    case .lda: name = "lda"
    case .ldx: name = "ldx"
    case .ldy: name = "ldy"
    case .lsr, .lsr_a: name = "lsr"
    case .mvn: name = "mvn"
    case .mvp: name = "mvp"
    case .nop: name = "nop"
    case .ora: name = "ora"
    case .pea: name = "pea"
    case .pei: name = "pei"
    case .per: name = "per"
    case .pha: name = "pha"
    case .phb: name = "phb"
    case .phd: name = "phd"
    case .phk: name = "phk"
    case .php: name = "php"
    case .phx: name = "phx"
    case .phy: name = "phy"
    case .pla: name = "pla"
    case .plb: name = "plb"
    case .pld: name = "pld"
    case .plp: name = "plp"
    case .plx: name = "plx"
    case .ply: name = "ply"
    case .rep: name = "rep"
    case .rol, .rol_a: name = "rol"
    case .ror, .ror_a: name = "ror"
    case .rti: name = "rti"
    case .rts: name = "rts"
    case .rtl: name = "rtl"
    case .sbc: name = "sbc"
    case .sec: name = "sec"
    case .sed: name = "sed"
    case .sei: name = "sei"
    case .sep: name = "sep"
    case .stp: name = "stp"
    case .sta: name = "sta"
    case .stx: name = "stx"
    case .sty: name = "sty"
    case .stz: name = "stz"
    case .tax: name = "tax"
    case .tay: name = "tay"
    case .txa: name = "txa"
    case .tsx: name = "tsx"
    case .txs: name = "txs"
    case .tya: name = "tya"
    case .txy: name = "txy"
    case .tyx: name = "tyx"
    case .tcd: name = "tcd"
    case .tdc: name = "tdc"
    case .tcs: name = "tcs"
    case .tsc: name = "tsc"
    case .trb: name = "trb"
    case .tsb: name = "tsb"
    case .wai: name = "wai"
    case .wdm: name = "wdm"
    case .xba: name = "xba"
    case .xbe: name = "xbe"
    case .xce: name = "xce"
    }
    return name
}
