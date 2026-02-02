package gui

import "../draw"
import "odinlib:util"


Container :: struct {}

container_render :: proc(ctx: ^Context, control: ^Control) {
    using ctx
    if true {
        draw_context->push_command(draw.Stroke_Rect {
            rect=util.rect_to_f(control.rect),
            color=draw.color_black,
            line_width=3,
        })
    } else {
        name := name(control)
        text_size := draw_context->measure_string(small_font, name)
        draw_context->push_command(draw.Draw_Text {
            text=name,
            font=small_font,
            rect=util.rect_to_f(
                {control.rect.x, control.rect.y, text_size.x, text_size.y}
            ),
            color=draw.color_black,
        })
        // Left
        draw_context->push_command(draw.Stroke_Line {
            pts={
                {control.rect.x, control.rect.y + text_size.y},
                {control.rect.x, control.rect.y + control.rect.h},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Bottom
        draw_context->push_command(draw.Stroke_Line {
            pts={
                {control.rect.x, control.rect.y + control.rect.h},
                {control.rect.x + control.rect.w, control.rect.y + control.rect.h},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Right
        // TODO: scroll bar if needed
        draw_context->push_command(draw.Stroke_Line {
            pts={
                {control.rect.x + control.rect.w, control.rect.y + control.rect.h},
                {control.rect.x + control.rect.w, control.rect.y},
            },
            color=draw.color_black,
            line_width=3,
        })
        // Top
        draw_context->push_command(draw.Stroke_Line {
            pts={
                {control.rect.x + text_size.x, control.rect.y},
                {control.rect.x + control.rect.w, control.rect.y},
            },
            color=draw.color_black,
            line_width=3,
        })
    }


    draw_context->push_clip_rect(control.rect)
    // Draw children union rect
    draw_context->push_command(draw.Stroke_Rect {
        rect=control.children_union_rect,
        color=draw.color_purple,
        line_width=2,
        style=.Dash,
    })
    draw_context->pop_clip_rect()
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
