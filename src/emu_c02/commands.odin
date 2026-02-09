package emu_c02

import "core:fmt"
import "core:os"
import "core:strings"

State :: struct {
    cpu: ^Cpu,
    memory: []u8,
    disassembler: ^Disassembler,
    running: bool,
}

Arg :: struct {
    str: string,
    number: int,
    is_number: bool,
}

Command :: struct {
    names, fmt: string,
    func: proc(state: ^State, args: []Arg),
}

Command_Result :: enum {
    Ok,
    Too_Few_Args,
    Invalid_Format,
    Not_Found,
}

commands := [?] Command {
    {"v,view", "n", view_memory},
    {"setf", ".n", set_cpu_flag},
    {"set", ".n", set_cpu_register},
    {"load", ".", load_program},
    {"q,quit,exit", "", quit},
}

parse_arg :: proc(buf: string) -> Arg {
    base := 16
    idx := 0
    number := 0
    if strings.has_prefix(buf, "0x") {
        idx += 2;
    } else if strings.has_prefix(buf, "$") {
        idx += 1;
    } else if (strings.has_prefix(buf, "0o")) {
        base = 8;
        idx += 2;
    } else if strings.has_prefix(buf, "0b") {
        base = 2;
        idx += 2;
    } else if strings.has_prefix(buf, "%") {
        base = 2;
        idx += 1;
    } else if strings.has_prefix(buf, "#") {
        base = 10;
        idx += 1;
    }
    is_number := true
    for c in buf[idx:] {
        digit := 0
        switch c {
        case '0'..='9':
            n := cast(int)(c - '0')
            digit = n if n < base else -1
        case 'a'..='f':
            digit = 10 + cast(int)(c - 'a') if base == 16 else -1
        }
        if digit > -1 {
            number *= base
            number += digit
        } else {
            number = 0
            is_number = false
            break
        }
    }
    return Arg { str=buf, number=number, is_number=is_number, } 
}

@(private="file")
view_memory :: proc(state: ^State, args: []Arg) {
}

@(private="file")
load_program :: proc(state: ^State, args: []Arg) {
    path := args[0].str
    if file, err := os.open(path); err == nil {
        os.read(file, state.memory[:])
        fmt.println("Loaded program")
    } else {
        fmt.printfln("Could not load %v", path)
    }
}


@(private="file")
set_cpu_flag :: proc(state: ^State, args: []Arg) {
    flag_name := args[0].str
    value := args[1].number
    flag := Status_Flag.Unused
    if strings.equal_fold(flag_name, "n") {
        flag = .Negative
    } else if strings.equal_fold(flag_name, "v") {
        flag = .Overflow
    } else if strings.equal_fold(flag_name, "b") {
        flag = .Break
    } else if strings.equal_fold(flag_name, "d") {
        flag = .Decimal
    } else if strings.equal_fold(flag_name, "i") {
        flag = .Interrupt_Disable
    } else if strings.equal_fold(flag_name, "z") {
        flag = .Zero
    } else if strings.equal_fold(flag_name, "c") {
        flag = .Carry
    }
    if flag != .Unused {
        cpu_set_flag(state.cpu, flag, value != 0)
    }
}

@(private="file")
set_cpu_register :: proc(state: ^State, args: []Arg) {
    reg_name := args[0].str
    value := args[1].number
    if strings.equal_fold(reg_name, "a") {
        state.cpu.a = cast(u8)value
    } else if strings.equal_fold(reg_name, "x") {
        state.cpu.x = cast(u8)value
    } else if strings.equal_fold(reg_name, "y") {
        state.cpu.y = cast(u8)value
    } else if strings.equal_fold(reg_name, "sp") {
        state.cpu.sp = cast(u8)value
    } else if strings.equal_fold(reg_name, "pc") {
        state.cpu.pc = cast(u16)value
    } else if strings.equal_fold(reg_name, "p") {
        state.cpu.p = transmute(bit_set[Status_Flag; u8])cast(u8)value
    }
}

@(private="file")
quit :: proc(state: ^State, args: []Arg) {
    state.running = false
}

command_match :: proc(command: ^Command, command_name: string, args: []Arg) -> Command_Result {
    name_iter := command.names
    for name in strings.split_iterator(&name_iter, ",") {
        if strings.equal_fold(command_name, name) {
            if len(args) < len(command.fmt) do return .Too_Few_Args
            for ch, i in command.fmt {
                if(ch == 'n' && !args[i].is_number) do return .Invalid_Format
            }
            return .Ok
        }
    }
    return .Not_Found
}
    
state_init :: proc(state: ^State, cpu: ^Cpu, memory: []u8, disasm: ^Disassembler) {
    state.cpu = cpu
    state.memory = memory
    state.disassembler = disasm
    state.running = true
}

do_command :: proc(state: ^State, _input: string) {
    command_args: [16]Arg
    num_args := 0
    input := _input
    command_name, ok := strings.split_iterator(&input, " ")
    if !ok do return
    for token in strings.split_iterator(&input, " ") {
        if len(token) > 0 && num_args < len(command_args) {
            command_args[num_args] = parse_arg(token)
            num_args += 1
        }
    }
    
    found_command: ^Command = nil
    result: Command_Result
    for &command in commands {
        result = command_match(&command, command_name, command_args[:num_args])
        if result == .Ok {
            found_command = &command
            break
        } else if result != .Not_Found {
            break
        }
    }
    switch result {
        case .Ok: found_command.func(state, command_args[:num_args])
        case .Too_Few_Args: // nc.printw("Too few argumrnts!\n")
        case .Invalid_Format: // nc.printw("Invalid format\n")
        case .Not_Found: // nc.printw("Not a valid command\n")
    }
}
