package gui

import "../util"
import "../draw"
import "core:strings"
import win "core:sys/windows"

Label :: struct {
    text: string,
    font: rawptr,
}

label :: proc(text: string, font: rawptr) -> Control_Construct {
    text:= strings.clone(text)
    control := Control_Construct {
        type=.Label,
        sizing=Sizing_Text{font=font, text=text, scale=DEFAULT_SIZING_TEXT_SCALE},
        flags={.Selectable, .Grow_Width},
        label=Label {
            text=text,
            font=font,
        }
    }
    return control
}

label_render :: proc(ctx: ^Context, control: ^Control) {
    using ctx
    draw_context->push_command(draw.Stroke_Rect {
        rect=control.rect,
        color=draw.color_blue,
        line_width=2,
    })
    if is_selected(control) {
        draw_context->push_command(draw.Fill_Rect {
            rect=control.rect,
            color={0.0, 0.0, 1.0, 0.3},
        })
    }
    draw_context->push_command(draw.Draw_Text {
        text=control.label.text,
        font=control.label.font,
        rect=control.rect,
        color=draw.color_black,
    })
}
