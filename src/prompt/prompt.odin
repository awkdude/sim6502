package main
import "core:fmt"
import sa "core:container/small_array"
import "core:unicode"
import "base:intrinsics"
import "core:unicode/utf8"
import d2d "lib"
import win "core:sys/windows"
import "odinlib:util"
import "core:log"

Command_Line :: struct {
    d2d_context: ^util.Direct2D_Context,
    buffer: sa.Small_Array(64, rune),
    cursor: int,
}


// NOTE: Only for Windows
translate_keycode :: proc(wparam: win.WPARAM) -> util.Keycode {
    keycode: util.Keycode = .Unknown
    switch wparam {
    case win.VK_LEFT:
        keycode = .Left
    case win.VK_RIGHT:
        keycode = .Right
    case win.VK_BACK:
        keycode = .Backspace
    case win.VK_RETURN:
        keycode = .Return
    }
    return keycode

}

prompt_init :: proc(command_line: ^Command_Line, d2d_context: ^util.Direct2D_Context) {
    command_line.d2d_context = d2d_context
}

prompt_update :: proc(command_line: ^Command_Line, event: util.Window_Event) {
// {{{ 
    // FIXME: window event struct changed
    switch event_data in event {
    case util.Char_Event:
        rune_char := cast(rune)event_data
        if !unicode.is_print(rune_char) do break 
        if command_line.cursor < sa.len(command_line.buffer) {
            sa.set(&command_line.buffer, command_line.cursor, rune_char)
        } else {
            sa.push_back(&command_line.buffer, rune_char)  
        }
        advance_cursor(command_line, 1)
    case util.Key_Event:
    #partial switch event_data.keycode {
        case .Left:
            advance_cursor(command_line, -1)
        case .Right:
            advance_cursor(command_line, 1)
        case .Backspace: 
            if command_line.cursor == sa.len(command_line.buffer) {                      
                sa.pop_back_safe(&command_line.buffer)
            } else {
                sa.set(&command_line.buffer, command_line.cursor, ' ')
            }
            advance_cursor(command_line, -1)
        case .Return: 
            str := utf8.runes_to_string(sa.slice(&command_line.buffer))
            defer delete(str)
            fmt.println(str)
        }
    case util.Window_Resize:
        log.debugf("Window resized to (%v, %v)", event_data.x, event_data.y)
    } 

    // if command_line.d2d_context.text_layout != nil {
    //     command_line.d2d_context.text_layout->Release()
    //     command_line.d2d_context.text_layout = nil
    // }
    util.com_safe_release(&command_line.d2d_context.text_layout)
    line_buffer_string := utf8.runes_to_string(
        sa.slice(&command_line.buffer),
        context.temp_allocator,
    )
    line_buffer_wide_string := clone_to_wide_string(line_buffer_string)
    render_target_size: d2d.D2D_SIZE_U
    command_line.d2d_context.render_target->GetPixelSize(&render_target_size)
    command_line.d2d_context.dwrite_factory->CreateTextLayout(
        raw_data(line_buffer_wide_string), 
        cast(u32)len(line_buffer_wide_string),
        command_line.d2d_context.text_format,
        cast(f32)render_target_size.width,
        cast(f32)render_target_size.height,
        &command_line.d2d_context.text_layout,
    )
//}}}
}

prompt_render_direct2d :: proc(command_line: ^Command_Line) {
// {{{
    assert(command_line != nil)
    assert(command_line.d2d_context != nil)
    assert(command_line.d2d_context.render_target != nil)
    render_target_size: d2d.D2D_SIZE_U
    command_line.d2d_context.render_target->GetPixelSize(&render_target_size)

    command_line.d2d_context.render_target->BeginDraw()
    command_line.d2d_context.render_target->Clear(util.D2D_COLOR(&color_black))
    if command_line.d2d_context.text_layout != nil {
        command_line.d2d_context.solid_color_brush->SetColor(util.D2D_COLOR(&color_white))
        command_line.d2d_context.render_target->DrawTextLayout(
            {}, 
            command_line.d2d_context.text_layout, 
            command_line.d2d_context.solid_color_brush, 
            {}
        )
        rect: d2d.D2D_RECT_F
        if true {
            x, y: f32
            hit_test_metrics: d2d.DWRITE_HIT_TEST_METRICS
            command_line.d2d_context.text_layout->HitTestTextPosition(
                cast(u32)command_line.cursor,
                win.FALSE,
                &x,
                &y,
                &hit_test_metrics,
            )
            rect = d2d.D2D_RECT_F {
                hit_test_metrics.left, 
                hit_test_metrics.top,
                hit_test_metrics.left + hit_test_metrics.width, 
                hit_test_metrics.top + hit_test_metrics.height,
            }
        } else {
            dots_per_inch := util.get_render_target_dpi(command_line.d2d_context.render_target)
            font_size_dip := cast(i32)command_line.d2d_context.text_format->GetFontSize()
            font_size_px := cast(f32)util.dip_to_px(font_size_dip, dots_per_inch)
            metrics: d2d.DWRITE_TEXT_METRICS
            command_line.d2d_context.text_layout->GetMetrics(&metrics)
            rect = d2d.D2D_RECT_F {
                metrics.left + metrics.width, 
                metrics.top + metrics.height,
                metrics.left + metrics.width + font_size_px, 
                metrics.top + metrics.height + font_size_px,
            }
        }
        command_line.d2d_context.solid_color_brush->SetColor(util.D2D_COLOR(&color_cyan))
        command_line.d2d_context.render_target->FillRectangle(
            &rect,
            command_line.d2d_context.solid_color_brush,
        )
    }
    command_line.d2d_context.render_target->EndDraw(nil, nil)
// }}}
}


advance_cursor :: proc(command_line: ^Command_Line, dx: int) {
    final := command_line.cursor + dx
    if final >= 0 && final < sa.cap(command_line.buffer) {
        command_line.cursor = final
    }
}
