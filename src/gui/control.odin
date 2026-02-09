#+feature using-stmt
package gui

import "odinlib:util"
import "core:log"
import "core:math"
import "core:strings"

Control_Flag :: enum {
    Activatable,
    Handle_Event_On_Hover,
    Selectable,
    Scrollable,
    Vertical_Layout,
    Fit_Children,
    Grow_Width,
    Grow_Height,
}

Deactive_Flag :: enum {
    Key_Escape,
    Mouse_Press_Outside,
    Mouse_Outside,
    Mouse_Release,
}

Control :: struct {
    index: int,
    rect: Rect,
    // pos_type: Position_Type,
    id: ID_Type,
    using data: Control_Data,
    flags: bit_set[Control_Flag],
    offset, padding, scroll_offset: vec2, 
    children_union_rect: Rect,
    type: Control_Type,
    parent: ^Control, 
    children: [dynamic]^Control,
    observer: Maybe(Observer),
}

Control_Data :: struct #raw_union {
    container: Container,
    text_box: Text_Box,
    button: Button,
    label: Label,
    group_box: Group_Box,
    slider: Slider,
}

update_layout :: proc(ctx: ^Context, root: ^Control = nil) {
// {{{
    if ctx.layout_updated {
        if root == nil do return
    }
    offset: vec2
    stack := make([dynamic]^Control, 0, ctx.num_controls, context.temp_allocator)
    root := root if root != nil else ctx.root_control
    append(&stack, root)
    // Reset pass
    for len(stack) > 0 {
        control := pop(&stack)
        control.offset = control.padding
        control.children_union_rect = {}
        #reverse for child in control.children {
            append(&stack, child)
        }
    }
    clear(&stack)
    append(&stack, root)

    // Relative positioning pass
    for len(stack) > 0 {
        control := pop(&stack)
        if control.parent != nil {
            using control.parent
            if .Grow_Width in control.flags {
                control.rect.w = rect.w - rect.x
            }
            log.assertf(
                .Grow_Height not_in control.flags, 
                "`%s` cannot have a growing height right now!",
                name(control)
            )
            position: vec2
            if .Vertical_Layout in flags {
                if (offset.y + control.rect.h) > rect.h {
                    offset.y = padding.y
                    offset.x = padding.x + control.rect.w
                }
                offset.y += padding.y + control.rect.h
            } else {
                if (offset.x + control.rect.w) > rect.w {
                    offset.x = padding.x
                    offset.y += padding.y + control.rect.h 
                } 
                position = offset
                offset.x += padding.x + control.rect.w
            }
            control.rect.x = position.x - scroll_offset.x
            control.rect.y = position.y - scroll_offset.y
            children_union_rect = util.union_rect(children_union_rect, control.rect)
        }
        #reverse for child in control.children {
            append(&stack, child)
        }
    }
    ctx.layout_updated = true
 // }}}
}

Extremity :: enum {
    Top,
    Bottom,
} 
scroll_control :: proc( // {{{
    ctx: ^Context,
    control: ^Control,
    arg: union {vec2, Extremity}
) 
{
    log.debugf("Scrolling %v by %v", name(control), arg)
    old_scroll_offset := control.scroll_offset
    switch arg in arg {
    case vec2:
        control.scroll_offset += util.scale_vec2(
            arg, 
            cast(f32)util.dip_to_px(32, ctx.dots_per_inch)
        )
        control.scroll_offset.x = math.clamp(
            control.scroll_offset.x,
            0,
            max(0, control.children_union_rect.w - control.rect.w)
        )
        control.scroll_offset.y = math.clamp(
            control.scroll_offset.y,
            0,
            max(0, control.children_union_rect.h - control.rect.h)
        )
        log.debugf("scroll offset: %v", control.scroll_offset.y)
    case Extremity:
        switch arg {
        case .Top:
            control.scroll_offset.y = 0
        case .Bottom:
            // FIXME:
            control.scroll_offset.y = max(0, control.children_union_rect.h - control.rect.h)
        }
    }
    if control.scroll_offset != old_scroll_offset {
        update_layout(ctx, control)
    }
}

// }}}

Observer :: struct {
    data: rawptr,
    callback: proc(data: rawptr, ctx: ^Context, control: ^Control, event: Event), 
}

add_observer :: proc(ctx: ^Context, control: ^Control, observer: Observer) {
    control.observer = observer
}

@(private)
index_children :: proc(ctx: ^Context, control: ^Control, start: int = 0) {
    if control == nil do return
    for i := start; i < len(control.children); i += 1 {
        control.children[i].index = i
    }
}

find_scrollable_parent :: proc(control: ^Control) -> (^Control, bool) {
    control := control
    for control != nil {
        if .Scrollable in control.flags {
            return control, true
        }
        control = control.parent
    }
    return nil, false
}

name :: proc(control: ^Control) -> string {
    if control == nil do return ""
    return strings.string_from_null_terminated_ptr(
        raw_data(control.id[:]), 
        len(control.id[:])
    )
}
