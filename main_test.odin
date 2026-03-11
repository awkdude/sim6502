package main

import emu "src/emu_c02"
import "core:testing"
import "core:strconv"
import "core:strings"
import "core:log"
import "src/gui"
import "core:mem"
import "odinlib:util"
import "src/draw"
import "base:runtime"

@(test) 
pool_allocs :: proc(t: ^testing.T) {
    pool: gui.Control_Pool
    allocator := gui.control_pool_allocator(&pool)
    for i in 0..<len(pool.buf) {
        new_control, alloc_err := new(gui.Control, allocator)
        testing.expect_value(t, alloc_err, nil)
    }
    free_all(allocator)
    for i in 0..<len(pool.buf) {
        new_control, alloc_err := new(gui.Control, allocator)
        testing.expect_value(t, alloc_err, nil)
    }

}

@(test)
argss :: proc(t: ^testing.T) {
    testing.expect_value(t, emu.parse_arg("$4000").number, 0x4000)
    testing.expect_value(t, emu.parse_arg("#4000").number, 4000)
    testing.expect_value(t, emu.parse_arg("%4000").number, 0)
    testing.expect_value(t, emu.parse_arg("%1001").number, 9)
    testing.expect_value(t, emu.parse_arg("0o10").number, 8)
    testing.expect_value(t, emu.parse_arg("0b10").number, 2)
}
