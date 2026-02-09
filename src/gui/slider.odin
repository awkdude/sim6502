package gui

import "odinlib:util"
import "../draw"
import "core:log"
import "core:math"

Slider :: struct {
    min_value, max_value, value: int,
}

slider :: proc(min_value, max_value: int, initial_value: Maybe(int) = nil) -> Control_Construct {
    log.assertf(
        min_value < max_value,
        "Min value (%v) should be less than max value (%v)", 
        min_value,
        max_value,
    )
    cons := Control_Construct {
        flags={.Activatable},
        type=.Slider,
        slider={
            min_value=min_value,
            max_value=max_value,
        },
        sizing=Sizing_DIP{
            dip={120.0, 40.0},
        }
    }
    cons.slider.value = initial_value.? or_else cons.slider.min_value
    cons.slider.value = math.clamp(cons.slider.value, cons.slider.min_value, cons.slider.max_value)
    return cons
}

slider_handle_event :: proc(
    ctx: ^Context,
    control: ^Control,
    event: util.Window_Event)
{
    slider := &control.slider
    old_value := slider.value

    set_value_by_mouse :: proc(control: ^Control, mouse_position: vec2) {
        slider_f := util.normalize_to_range(
            cast(f32)(mouse_position.x - control.rect.x),
            0.0,
            cast(f32)control.rect.w,
            cast(f32)control.slider.min_value,
            cast(f32)control.slider.max_value
        )
        control.slider.value = cast(int)math.round(slider_f)
    }
    #partial switch event.type {
    case .Mouse_Button:
        // if !event.mouse_button.pressed ||
        // !util.point_in_rect(event.mouse_button.position, control.rect) 
        // {
        //     set_active(ctx, nil)
        // }
        set_value_by_mouse(control, event.mouse_button.position)
    case .Mouse_Move:
        set_value_by_mouse(control, event.vec2)
    case .Key:
        if event.key.pressed {
            // if event.key.keycode == util.KEY_ESCAPE {
            //     set_active(ctx, nil)
            // } 
            if event.key.keycode == util.KEY_LEFT {
                slider.value -= 1
            } else if event.key.keycode == util.KEY_RIGHT {
                slider.value += 1
            }
        }
    }
    slider.value = math.clamp(slider.value, slider.min_value, slider.max_value)
    if slider.value != old_value {
        push_event(ctx, Event { control=control, type=.Slider_Change, slider=slider.value })
    }
}

slider_render :: proc(ctx: ^Context, control: ^Control) {
    slider := &control.slider
    draw.push_command(ctx.draw_context, draw.Stroke_Rect {
        rect=rect_to_f(control.rect),
        color=draw.color_green,
        line_width=2,
    })
    fill_rect := Rect {
        x=control.rect.x,
        y=control.rect.y,
        w=cast(i32)util.normalize_to_range(
            cast(f32)slider.value,
            cast(f32)slider.min_value,
            cast(f32)slider.max_value,
            cast(f32)0.0,
            cast(f32)control.rect.w,
        ),
        h=control.rect.h,
    }
    draw.push_command(ctx.draw_context, draw.Fill_Rect {
        rect=rect_to_f(fill_rect),
        color=draw.color_red,
    })
}
