package gui

import "../draw"
import "odinlib:util"
import "core:log"
import "base:intrinsics"

// TODO: Make a Create_Control struct for constructing controls
Control_Construct :: struct {
    using data: Control_Data,
    type: Control_Type,
    flags: bit_set[Control_Flag],
    children: []Control_Construct,
    sizing: Sizing,
}

DEFAULT_SIZING_TEXT_SCALE :: util.vec2f { 1.1, 1.1 }

Sizing_Text :: struct {
    font: ^draw.Font,
    text: string,
    scale: util.vec2f,
}

Sizing_DIP :: struct {
    using dip: vec2,
}

Sizing :: union {
    Sizing_Text,
    Sizing_DIP,
}

create_control :: proc(
    ctx: ^Context, 
    id_string: string,
    cons: Control_Construct,
    parent: ^Control = nil) -> ^Control 
{ 
 // {{{
    parent := parent if parent != nil else ctx.root_control
    log.assertf(
        cons.type in allowed_child_types[parent.type],
        "%v cannot be a child of a %v",
        cons.type, parent.type
    )
    id := make_id(id_string)
    if id != NIL_ID do log.assertf(id not_in ctx.control_map, "%v already exists!", id_string)
    control := new_clone(
        Control {
            id=id,
            flags=cons.flags,
            type=cons.type,
            data=cons.data,
        }, 
        ctx.control_allocator
    )
    
    initial_cap := 8 if allowed_child_types[cons.type] != nil else 1
    control.children = make([dynamic]^Control, 0, initial_cap)
    idx := len(parent.children)
    append(&parent.children, control)
    ctx.num_controls += 1
    // TODO: Combine this statement with assertf
    if id != NIL_ID do ctx.control_map[id] = control
    control.index = idx
    control.parent = parent
    switch sizing in cons.sizing {
    case Sizing_Text:
        text_size := vec2 {
            draw.get_text_width(sizing.font, sizing.text),
            draw.get_text_height(sizing.font),
        }
        control.rect = util.size_to_rect(util.scale_vec2(text_size, sizing.scale))
    case Sizing_DIP:
        dpi := ctx.dots_per_inch
        control.rect = util.size_to_rect(vec2{
            util.dip_to_px(sizing.dip.x, dpi),
            util.dip_to_px(sizing.dip.y, dpi),
        })
    }
    for child_cons in cons.children {
        append(&control.children, create_control(ctx, "", child_cons, control))
    }
    log.debugf("Created `%v`", name(control))
    ctx.layout_updated = false
    return control
 // }}}
}

delete_control :: proc(ctx: ^Context, control: ^Control) {
// {{{
    // FIXME: step through this in debugger!
    temp_stack := make([dynamic]^Control, context.temp_allocator)
    stack := make([dynamic]^Control, context.temp_allocator)
    append(&temp_stack, control)
    for len(temp_stack) > 0 {
        control := pop(&temp_stack)
        append(&stack, control)
        #reverse for child in control.children {
            append(&temp_stack, child)
        }
    }
    for c in pop_safe(&stack) {
        intrinsics.debug_trap()
        index := c.index
        ordered_remove(&c.parent.children, c.index)
        ctx.num_controls -= 1
        index_children(ctx, c.parent, index)
        // TODO: delete(c.children)
        if c.id != NIL_ID {
            delete_key(&ctx.control_map, c.id)
        }
        free(c, ctx.control_allocator)
    }
    ctx.layout_updated = false
// }}}
} 

