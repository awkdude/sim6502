package emu_c02

Bus :: struct {
    data: []u8,
}

bus_init :: proc(bus: ^Bus) {
    bus.data = make([]u8, 64 * 1024)
}

bus_read :: proc(bus: ^Bus, addr: uint) -> u8 {
    return bus.data[addr % len(bus.data)]
}

bus_read16 :: proc(bus: ^Bus, addr: uint) -> u16 {
    dbl_byte := cast(u16)bus_read(bus, addr)
    dbl_byte |= (cast(u16)bus_read(bus, addr+1) << 8)
    return dbl_byte
}

bus_write :: proc(bus: ^Bus, addr: uint, byte: u8) {
    bus.data[addr % len(bus.data)] = byte
}

bus_write16 :: proc(bus: ^Bus, addr: uint, dbl_byte: u16) {
    bus_write(bus, addr, u8(dbl_byte & 0xff))
    bus_write(bus, addr+1, u8(dbl_byte >> 8))
}
