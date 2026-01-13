#+test

package main

import emu "emu_c02"
import "core:testing"
import "core:strconv"
import "core:strings"
import "core:log"

@(test)
argss :: proc(t: ^testing.T) {
    testing.expect_value(t, emu.parse_arg("$4000").number, 0x4000)
    testing.expect_value(t, emu.parse_arg("#4000").number, 4000)
    testing.expect_value(t, emu.parse_arg("%4000").number, 0)
    testing.expect_value(t, emu.parse_arg("%1001").number, 9)
    testing.expect_value(t, emu.parse_arg("0o10").number, 8)
    testing.expect_value(t, emu.parse_arg("0b10").number, 2)
}
