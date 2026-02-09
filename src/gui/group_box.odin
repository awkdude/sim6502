package gui

import "core:container/bit_array"

Bit_Array :: bit_array.Bit_Array

Group_Box :: struct {
    using selection: struct #raw_union {
        multiple: Bit_Array,
        single: Maybe(int),
    },
    is_multiselect: bool,
}

find_group_box_parent :: proc(control: ^Control) -> (^Control, bool) {
    parent := control.parent
    for parent != nil {
        if parent.type == .Group_Box do return parent, true
        parent = parent.parent
    }
    return nil, false
}

select_control :: proc(control: ^Control, reset: bool = false) {
    if parent, found := find_group_box_parent(control); found {
        if parent.group_box.is_multiselect {
            if reset do bit_array.clear(&parent.group_box.multiple)
            bit_array.set(&parent.group_box.multiple, control.index)
        } else {
            parent.group_box.single = control.index  
        }
    }
}

is_selected :: proc(control: ^Control) -> bool {
    if parent, found := find_group_box_parent(control); found {
        if parent.group_box.is_multiselect {
            is_set, ok := bit_array.get(&parent.group_box.multiple, control.index)
            return is_set && ok
        } else {
            select_index, ok := parent.group_box.single.?
            return select_index == control.index if ok else false
        }
    }
    return false
}
