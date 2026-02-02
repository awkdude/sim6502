package gui

import "odinlib:util"
import "../d2d"
import "../draw"
import win "core:sys/windows"
import "core:unicode/utf8"
import "core:unicode"
import "core:math"
import "core:time"
import "core:slice"
import "core:log"

// TODO: rename this to number box...or something like that

Text_Box :: struct {
    buffer: [8]rune,
    len, caret_position: int,
    input_type: util.Radix,
    font: rawptr,
}

text_box :: proc(font: rawptr, initial_text: string = "") -> Control_Construct {
    cons := Control_Construct {
        flags={.Activatable},
        type=.Text_Box,
        text_box=Text_Box{
            input_type=.Hex,
            font=font,
        },
    }
    if initial_text != "" {
        text_runes := utf8.string_to_runes(initial_text, context.temp_allocator)
        copy(cons.text_box.buffer[:], text_runes)
    } else {
        slice.fill(cons.text_box.buffer[:], '0')
        cons.text_box.len = len(cons.text_box.buffer)
    }
    cons.sizing = Sizing_Text{
        font=font,
        scale=DEFAULT_SIZING_TEXT_SCALE,
        text=utf8.runes_to_string(
            cons.text_box.buffer[:cons.text_box.len],
            context.temp_allocator
        ),
    }
    return cons
}

text_box_handle_event :: proc(
    ctx: ^Context,
    control: ^Control, 
    event: util.Window_Event)
{
    text_box := &control.text_box
    #partial switch event.type {
    case .Char_Input:
        using control
        // FIXME: Increment length only if cursor is at the end. Make a proc for this
        if util.is_digit_in_radix(cast(rune)event.char_codepoint, .Hex) {
            c := unicode.to_upper(event.char_codepoint)
            text_box.buffer[text_box.caret_position] = c
            if text_box.caret_position == text_box.len && text_box.len < len(text_box.buffer) {
                text_box.len += 1
            }
            text_box.caret_position = util.wrap(
                text_box.caret_position + 1, 
                len(text_box.buffer)
            )
            push_event(ctx, Event{control=control, type=.Text_Change})
        }
    case .Key:
        // if event.key.keycode == util.KEY_ESCAPE {
        //     set_active(ctx, nil)
        // } 
        if event.key.keycode == util.KEY_BACKSPACE {
            text_box.buffer[text_box.caret_position] = '0'
            text_box.caret_position = util.wrap(
                text_box.caret_position - 1,
                len(text_box.buffer)
            )
        } else if event.key.keycode == util.KEY_SPACE {
            text_box.caret_position = util.wrap(
                text_box.caret_position + 1,
                len(text_box.buffer)
            )
            number, ok := text_box_get_value(ctx, control)
            assert(ok, "Text box is not a real number!")
            log.debugf("Text: %s; Number: %d", text_box.buffer[:text_box.len], number)
        }
    case .Mouse_Button:
        // if !util.point_in_rect(ctx.mouse_position, control.rect) {
        //     set_active(ctx, nil)
        // }
    }
}

text_box_set_value :: proc(ctx: ^Context, control: ^Control, number: int) {
    text_box := &control.text_box
    number := math.abs(number)
    #partial switch text_box.input_type {
    case .Hex:
        for i := len(text_box.buffer) - 1; i >= 0; i -= 1 {
            digit_value := number % 16
            c: int
            if digit_value < 10 {
                c = '0' + digit_value
            } else {
                c = 'A' + (digit_value - 10) 
            }
            text_box.buffer[i] = cast(rune)c
            number /= 16
        }
    case:
        unimplemented()
    }
    text_box.len = len(text_box.buffer)
}

text_box_get_value :: proc(ctx: ^Context, control: ^Control) -> (int, bool) {
    result := 0
    text_box := &control.text_box
    #partial switch text_box.input_type {
    case .Hex:
        for i in 0..<text_box.len {
            result *= 16
            c := text_box.buffer[i]
            if c >= '0' && c <= '9' {
                result += int(c - '0')
            } else if c >= 'A' && c <= 'F' {
                result += int(c - 'A') + 10
            } else if c >= 'a' && c <= 'f' {
                result += int(c - 'a') + 10
            } else {
                return result, false
            }
        }
    }
    return result, true
}


text_box_render :: proc(ctx: ^Context, control: ^Control) {
    using ctx
    text_box := &control.text_box
    draw_context->push_command(draw.Stroke_Rect{
        rect=control.rect,
        color=draw.color_black,
        line_width=2,
    })
    control_text: string
    if control.text_box.len > 0 {
        control_text = utf8.runes_to_string(
            control.text_box.buffer[:control.text_box.len],
            context.temp_allocator
        )
        draw_context->push_command(draw.Draw_Text {
            text=control_text,
            font=control.text_box.font,
            rect=control.rect,
            color=draw.color_black,
        })
        // FIXME: Doesn't deal with text_box.len being 0
        if ctx.active_control == control {
            caret_rect, ok := draw_context->get_char_rect(
                control.text_box.font,
                control_text,
                text_box.caret_position
            )
            caret_rect.x += control.rect.x
            caret_rect.y += control.rect.y
            secs := time.duration_seconds(time.tick_since({}))
            v := cast(f32)math.sin(math.TAU * secs)
            fill_color := draw.color_orange
            fill_color.a = 1.0 if v >= 0.0 else 0.0
            draw_context->push_command(draw.Fill_Rect {
                rect=caret_rect,
                color=util.Color_f{ 1.0, 0.0, 0.0, 0.4 },
            })
        }
    }
}
