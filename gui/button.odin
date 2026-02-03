package gui

import "odinlib:util"
import "core:slice"
import "core:time"
import "core:math"
import "core:math/ease"
import "../draw"

Button :: struct {
    label_buf: [16]u8,
    label_len: int,
}

button :: proc(text: string, font: ^draw.Font, scale: util.vec2f = {2.6, 1}) -> Control_Construct {
    cons := Control_Construct {
        flags={.Activatable},
        sizing=Sizing_DIP{dip={120, 45}},
        type=.Button,
        children=slice.clone([]Control_Construct{label(text, font)}, context.temp_allocator)
    }
    return cons
}

button_render :: proc(using ctx: ^Context, control: ^Control) {
    fill_color := draw.color_red
    if ctx.active_control == control {
        fill_color = draw.color_white
    } else if ctx.hovered_control == control {
        // TODO: Use easing color
        duration := time.tick_since(ctx.hover_tick)
        t := min(1.0, cast(f32)duration / cast(f32)EASE_DURATION)
        fill_color = math.lerp(
            draw.color_red,
            draw.color_yellow,
            ease.ease(cast(ease.Ease)ctx.ease_type, t)
        )
        // fill_color = draw.color_yellow
    }
    draw.push_command(draw_context, draw.Fill_Rect{
        rect=rect_to_f(control.rect),
        color=fill_color,
    })
    // draw_context->push_command(draw.Draw_Text {
    //     text=transmute(string)control.button.label_buf[:control.button.label_len],
    //     font=ctx.font,
    //     rect=control.rect,
    //     color=draw.color_black,
    // })
}

button_handle_event :: proc(
    ctx: ^Context,
    control: ^Control,
    event: util.Window_Event) 
{
    in_rect := util.point_in_rect(ctx.mouse_position, control.rect)
    if event.type == .Mouse_Move {
        // if !in_rect {
        //     set_active(ctx, nil)
        // }
    } else if in_rect && event.type == .Mouse_Button && !event.mouse_button.pressed {
        set_active(ctx, nil)
        push_event(ctx, Event{control=control, type=.Button_Press})
    }
}
