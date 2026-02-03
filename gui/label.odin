package gui

import "odinlib:util"
import "../draw"
import "core:strings"
import win "core:sys/windows"

Label :: struct {
    text: string,
    font: ^draw.Font,
}

label :: proc(text: string, font: ^draw.Font) -> Control_Construct {
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

label_render :: proc(using ctx: ^Context, control: ^Control) {
    draw.push_command(draw_context, draw.Stroke_Rect {
        rect=rect_to_f(control.rect),
        color=draw.color_blue,
        line_width=2,
    })
    if is_selected(control) {
        draw.push_command(draw_context, draw.Fill_Rect {
            rect=rect_to_f(control.rect),
            color={0.0, 0.0, 1.0, 0.3},
        })
    }
    draw.push_command(draw_context, draw.Draw_Text {
        text=control.label.text,
        font=control.label.font,
        rect=rect_to_f(control.rect),
        color=draw.color_black,
    })
}
