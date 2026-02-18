#+build !windows
package main

import "core:math"
import "core:time"
import "core:fmt"
import "core:thread"
import "core:unicode"
import "core:testing"
import "core:strings"
import "core:bytes"
import "core:os"
import "core:log"
import "core:dynlib"
import "core:path/filepath"
import "draw"
import "platform"
import "util"
import gl "vendor:OpenGL"

when util.PLATFORM_BACKEND == "native" {
vec2 :: util.vec2

WINDOW_WIDTH : i32 : 600
WINDOW_HEIGHT: i32 : 600
// GRAPHICS :: util.Window_Graphics.Software

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
	(^rawptr)(p)^ = platform.get_proc_address(name)
}

running: bool
clear_color: util.Color_f

draw_context: draw.Draw_Context

process_events :: proc() {
    platform_events: [64]platform.Window_Event
    num_events := platform.poll_window_events(platform_events[:])
    window_event: Maybe(util.Window_Event)
    // TODO: Only use one Window_Event and fix any differences so this works
    for event in platform_events[:num_events] {
        switch event.type {
        case .Key:
            window_event = util.Window_Event {
                type=.Key,
                key={
                    // TODO: translate
                    keycode=0,
                    pressed=event.key.pressed
                }
            }
            // if event.key.keycode < 256 {
            //     util.modify_bit(U.input.keyboard[:], cast(uint)event.key.keycode, 
            //         event.key.pressed)
            //     if event.key.pressed {
            //         util.modify_bit(U.input.keys_pressed[:], cast(uint)event.key.keycode, true)
            //     } else {
            //         util.modify_bit(U.input.keys_released[:], cast(uint)event.key.keycode, true)
            //     }
            // }

        case .Mouse_Button:
        case .Mouse_Motion:
            window_size := platform.get_window_size() 
            clear_color = {
                cast(f32)event.vec2.y / cast(f32)window_size.y, 
                0.0,
                cast(f32)event.vec2.x / cast(f32)window_size.x, 
                1.0
            }
        case .Mouse_Wheel:
        case .Character:
        case .Resize:
        case .Close:
        case .Gain_Focus:
        case .Lose_Focus:
        case .Mouse_Enter: 
        case .Mouse_Leave:
        case .Display_Change:
        }
        if event, ok := window_event.?; ok {
            // TODO:
            log.debug(window_event)
            src.handle_event(event)
        }
    }
}

target_frame_interval_usec :: 16666 * time.Microsecond

main :: proc() {
    context.logger = log.create_console_logger()
    context.logger.options -= {.Date}
    if !platform.init_window(
        strings.unsafe_string_to_cstring("VGMPlay"),
        WINDOW_WIDTH,
        WINDOW_HEIGHT, 
        0 // cast(i32)GRAPHICS
    ) {
        return
    }
    running = true
    src.init({})
    for running {
        process_events()
        sw_context := cast(^draw.SW_Context)draw_context.data
        platform.get_framebuffer(
            &sw_context.pixmap.pixels, 
            &sw_context.pixmap.w,
            &sw_context.pixmap.h,
        )
        src.update({})
        draw._fill(
            &sw_context.pixmap, 
            clear_color
        )
        platform.show_framebuffer()
        util.wait_frame_interval(&previous_frame_tick, target_frame_interval) 
    }
}
}
