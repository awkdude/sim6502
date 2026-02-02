package gui

import "base:runtime"
import "core:log"
import "core:container/queue"
import "odinlib:util"
import "../draw"
import "core:time"
import "core:math"
import "core:math/ease"

vec2 :: util.vec2
vec2f :: util.vec2f
Rect :: util.Rect
Rectf :: util.Rectf

rect_to_f :: proc(r: Rect) -> Rectf {
    return {
        x=cast(f32)r.x,
        y=cast(f32)r.y,
        w=cast(f32)r.w,
        h=cast(f32)r.h,
    }
}

vec2_to_f :: proc(v: vec2) -> vec2f { 
    return { cast(f32)v.x, cast(f32)v.y }
}

// NOTE: Should this be aligned?
ID_Type :: [16]u8
NIL_ID: ID_Type : {} 

EASE_DURATION :: 300 * time.Millisecond

make_id :: proc(s: string) -> ID_Type {
    id: ID_Type
    copy(id[:], s)
    return id
}

Context :: struct {
    handle_platform_command: proc(_: util.Platform_Command),
    control_allocator: runtime.Allocator,
    root_control: ^Control,
    hovered_control, active_control, parent_control: ^Control,
    last_control: ^Control,
    control_map: map[ID_Type]^Control,
    mouse_position: vec2,
    draw_context: ^draw.Draw_Context,
    font, small_font: draw.Font,
    layout_updated: bool,
    hovered_by_keyboard: bool,
    events: queue.Queue(Event),
    num_controls: int,
    hover_tick: time.Tick,
    ease_type: int,
}

context_init :: proc(ctx: ^Context, allocator := context.allocator) {
// {{{
    ctx^ = {}
    ctx.control_allocator = allocator
    assert(ctx.draw_context != nil, "No draw context set")
    assert(ctx.draw_context.data != nil, "No backend data pointer set")
    assert(ctx.draw_context.vtable != nil, "No backend vtable set")
    dots_per_inch := ctx.draw_context->get_render_target_dpi()
    padding_value := util.dip_to_px(48, dots_per_inch)
    padding := vec2{padding_value, padding_value}
    ctx.small_font = ctx.draw_context->create_font("consolas", 20)
    render_size := ctx.draw_context->get_render_target_size()
    ctx.root_control = new_clone(
        Control {
            id=make_id("root"),
            rect={
                padding.x, 
                padding.y, 
                render_size.x - padding.x * 2,
                render_size.y - padding.y * 2,
            },
            // DELETE .Vertical_Layout
            flags={.Scrollable, },
            padding=padding,
            offset=padding,
            children=make([dynamic]^Control, 0, 64)
        },
        ctx.control_allocator
    )
    queue.init(&ctx.events)
// }}}
}


change_ease :: proc(ctx: ^Context, dec: bool = false) {
    ctx.ease_type = util.wrap(
        ctx.ease_type - 1 if dec else ctx.ease_type + 1,
        len([ease.Ease]rawptr)
    )
    ctx.hover_tick = time.tick_now()
    log.debugf("Changed ease to %v", cast(ease.Ease)ctx.ease_type)
}

context_handle_event :: proc(ctx: ^Context, window_event: util.Window_Event) {
// {{{
    update_layout(ctx)
    #partial switch window_event.type {
    case .Key:
        // TODO: Use TAB and ALT+TAB to navigate
        if window_event.key.pressed {
            switch window_event.key.keycode {
            case util.KEY_UP:
                //move_key_hover(ctx, .Up)
            case util.KEY_DOWN:
                //move_key_hover(ctx, .Down)
            case util.KEY_LEFT:
                //move_key_hover(ctx, .Left)
            case util.KEY_RIGHT:
                //move_key_hover(ctx, .Right)
            case util.KEY_HOME:
                if ctx.hovered_control != nil {
                    scrollable_control, found := find_scrollable_parent(ctx.hovered_control)
                    if found do scroll_control(ctx, scrollable_control, .Top)
                }
            case util.KEY_END:
                if ctx.hovered_control != nil {
                    scrollable_control, found := find_scrollable_parent(ctx.hovered_control)
                    if found do scroll_control(ctx, scrollable_control, .Bottom)
                }
            case util.KEY_PAGEUP:
                change_ease(ctx)
            case util.KEY_PAGEDOWN:
                change_ease(ctx, true)
            }

        }
    case .Mouse_Move:
        /* TODO: Only set the ctx.mouse_position and 
        set a flag to look search control tree to find hovered
        */
        ctx.mouse_position = window_event.vec2
        hovered_control: ^Control
        stack := make([dynamic]^Control, context.temp_allocator)
        append(&stack, ctx.root_control)
        for len(stack) > 0 {
            control := pop(&stack)
            if util.point_in_rect(window_event.vec2, control.rect) {
                hovered_control = control
                if len(control.children) == 0 do break
                for child in control.children {
                    append(&stack, child)
                }
            }
        }
        set_hover(ctx, hovered_control)
    case .Mouse_Wheel:
        scroll_offset := vec2{window_event.vec2.x, -window_event.vec2.y}
        log.debug(window_event.vec2)
        if ctx.hovered_control != nil {
            scrollable_control, found := find_scrollable_parent(ctx.hovered_control)
            if found do scroll_control(ctx, scrollable_control, scroll_offset)
        }
    case .Mouse_Button:
        if window_event.mouse_button.pressed {
            clicked_control: ^Control
            // stack := make([dynamic]^Control, context.temp_allocator)
            // append(&stack, ctx.root_control)
            // for len(stack) > 0 {
            //     control := pop(&stack)
            //     if util.point_in_rect(window_event.mouse_button.position, control.rect) {
            //         clicked_control = control
            //         if len(control.children) == 0 do break
            //         for child in control.children {
            //             append(&stack, child)
            //         }
            //     }
            // }
            // FIXME: Check for active control
            if ctx.hovered_control != nil && !ctx.hovered_by_keyboard {
                clicked_control = ctx.hovered_control
            }
            if clicked_control != nil {
                if window_event.mouse_button.button == .Left {
                    if .Activatable in clicked_control.flags {
                        // TODO: set_active(ctx, clicked_control)
                        ctx.active_control = clicked_control
                        log.debugf("`%v` control is active!", name(clicked_control))
                    }
                } else if window_event.mouse_button.button == .Right {
                    delete_control(ctx, clicked_control)
                }
            } else {
                ctx.active_control = nil
                log.debug("NO active")
            }
        }
    case .Window_Resize:
        window_rect := util.size_to_rect(window_event.vec2)
        root_rect := util.size_to_rect(window_event.vec2 - (ctx.root_control.padding * 2))
        ctx.root_control.rect = util.rect_centered_in_rect(
            root_rect,
            window_rect,
        )
        ctx.layout_updated = false
        // TODO:
    }
    if ctx.active_control != nil {
        // TODO: integrate this code in previous switch statement
        // {{{ Check deactive
        deactivate := false
        deactive_flags := deactive_table[ctx.active_control.type]
        #partial switch window_event.type {
        case .Key:
            if .Key_Escape in deactive_flags && window_event.key.keycode == util.KEY_ESCAPE {
                deactivate = true
            }
        case .Mouse_Button:
            if window_event.mouse_button.pressed {
                if .Mouse_Press_Outside in deactive_flags &&
                !util.point_in_rect(window_event.mouse_button.position, ctx.active_control.rect) 
                {
                    deactivate = true
                }
            } else {
                if .Mouse_Release in deactive_flags {
                    deactivate = true
                }
            }
        case .Mouse_Move:
            if .Mouse_Outside in deactive_flags &&
            !util.point_in_rect(window_event.vec2, ctx.active_control.rect) 
            {
                deactivate = true
            }
        }
        //  }}}
        if deactivate {
            set_active(ctx, nil)
        } else {
            event_proc := handle_event_proc_table[ctx.active_control.type]
            event_proc(ctx, ctx.active_control, window_event)
        }
    }  else if ctx.hovered_control != nil && .Handle_Event_On_Hover in ctx.hovered_control.flags {
        event_proc := handle_event_proc_table[ctx.hovered_control.type]
        event_proc(ctx, ctx.hovered_control, window_event)
    }
// }}}
} 

context_render :: proc(using ctx: ^Context) {
// {{{
    update_layout(ctx)
    draw_context->push_command(draw.Clear{color=draw.color_white})
    stack := make([dynamic]^Control, context.temp_allocator)
    append(&stack, ctx.root_control)
    clip_rect := util.size_to_rect(draw_context->get_render_target_size())
    draw_context->push_clip_rect(clip_rect)
    theta := time.duration_seconds(time.tick_since({}))
    thick_max: f64 = 20.0
    v := thick_max * (math.sin(theta) * 0.5 + 0.5)
    for len(stack) > 0 {
        control := pop(&stack)
        if control == hovered_control {
            draw_context->push_command(draw.Stroke_Rect{
                color=draw.color_cyan,
                line_width=cast(i32)v,
                rect=clip_rect,
            })
        }
        render_proc := render_proc_table[control.type]
        if render_proc != nil do render_proc(ctx, control)
        draw_context->pop_clip_rect()
        #reverse for child in control.children {
            append(&stack, child)
            clip_rect = control.rect
            draw_context->push_clip_rect(clip_rect)
        }
    }
// }}}
}

set_hover :: proc(ctx: ^Context, control: ^Control) { 
// {{{
    // FIXME:
    old_hovered := ctx.hovered_control
    ctx.hovered_control = control
    if old_hovered != ctx.hovered_control {
        ctx.hover_tick = time.tick_now()
        log.debugf("%v is hovered", name(ctx.hovered_control))
        if ctx.hovered_control != nil {
            ctx.handle_platform_command({
                type=.Change_Mouse_Cursor, 
                cursor_type=mouse_cursor_on_hover[ctx.hovered_control.type],
            })
        } else {
            ctx.handle_platform_command({type=.Change_Mouse_Cursor, cursor_type=.Normal})
            log.debugf("Unhovered")
        }
    }
// }}}
} 

set_active :: proc(ctx: ^Context, control: ^Control) { 
// {{{
    // FIXME:
    old_active := ctx.active_control
    ctx.active_control = control
    if old_active != ctx.active_control {
        if ctx.active_control != nil {
            log.debugf("%v is active", name(ctx.active_control))
        } else {
            log.debugf("No active")
        }
    }
 // }}}
}

is_hover :: proc(ctx: ^Context, control: ^Control) -> bool {
    return ctx.hovered_control == control
}

is_active :: proc(ctx: ^Context, control: ^Control) -> bool {
    return ctx.active_control == control
}

is_hover_set :: proc(ctx: ^Context) -> bool {
    return ctx.hovered_control != nil
}

is_active_set :: proc(ctx: ^Context) -> bool {
    return ctx.active_control != nil
}
control_by_id :: proc(ctx: ^Context, id: ID_Type) -> ^Control {
    return ctx.control_map[id]
}

Traverse :: enum {
    Up,
    Down,
    Left,
    Right,
}

move_key_hover :: proc(ctx: ^Context, traverse: Traverse) { 
// {{{
    if !ctx.hovered_by_keyboard {
        ctx.active_control = ctx.root_control
        ctx.hovered_by_keyboard = true
    } else {
        if ctx.active_control == nil {
            ctx.active_control = ctx.root_control
        } else {
            // TODO:
            switch traverse {
            case .Up:
            case .Down:
            case .Left:
            case .Right:
            }
        }
    }
 // }}}
}

// {{{ Events
Event_Type :: enum {
    Button_Press,
    Text_Change,
    Slider_Change,
}

Event :: struct {
    control: ^Control,
    type: Event_Type,
    using data: struct {
        slider: int,
    }
}

push_event :: proc(ctx: ^Context, event: Event) {
    queue.push_back(&ctx.events, event)
    if event.control != nil {
        if observer, ok := event.control.observer.?; ok {
            observer.callback(event.control, ctx, event.control, event)
        }
    }
}

next_event :: proc(ctx: ^Context) -> (Event, bool) {
    return queue.pop_back_safe(&ctx.events)
}
// }}}
