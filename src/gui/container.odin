package gui

import "../draw"
import "odinlib:util"


Container :: struct {}

container_render :: proc(ctx: ^Context, control: ^Control) {
    when true {
        draw.push_command(ctx.draw_context, draw.Stroke_Rect {
            rect=rect_to_f(control.rect),
            color=draw.color_black,
            line_width=3,
        })
    } else {
        name := name(control)
        text_size := draw.measure_string(ctx.draw_context, small_font, name)
        draw.push_command(ctx.draw_context, draw.Draw_Text {
            text=name,
            font=small_font,
            rect=util.rect_to_f(
                {control.rect.x, control.rect.y, text_size.x, text_size.y}
            ),
            color=draw.color_black,
        })
        // Left
        draw.push_command(ctx.draw_context, draw.Stroke_Line {
            pts={
                {control.rect.x, control.rect.y + text_size.y},
                {control.rect.x, control.rect.y + control.rect.h},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Bottom
        draw.push_command(ctx.draw_context, draw.Stroke_Line {
            pts={
                {control.rect.x, control.rect.y + control.rect.h},
                {control.rect.x + control.rect.w, control.rect.y + control.rect.h},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Right
        // TODO: scroll bar if needed
        draw.push_command(ctx.draw_context, draw.Stroke_Line {
            pts={
                {control.rect.x + control.rect.w, control.rect.y + control.rect.h},
                {control.rect.x + control.rect.w, control.rect.y},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Top
        draw.push_command(ctx.draw_context, draw.Stroke_Line {
            pts={
                {control.rect.x + text_size.x, control.rect.y},
                {control.rect.x + control.rect.w, control.rect.y},
            },
            color=draw.color_black,
            line_width=3,
        })
    }


    // draw.push_clip_rect(ctx.draw_context, control.rect)
    // Draw children union rect
    draw.push_command(ctx.draw_context, draw.Stroke_Rect {
        rect=rect_to_f(control.children_union_rect),
        color=draw.color_purple,
        line_width=2,
        style=.Dash,
    })
    // draw.pop_clip_rect(ctx.draw_context)
}

container_handle_event :: proc(
    ctx: ^Context, 
    control: ^Control,
    event: util.Window_Event) 
{
    #partial switch event.type {
    case .Mouse_Wheel:
    case .Key:
    }
}
