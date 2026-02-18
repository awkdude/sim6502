#+feature using-stmt
package src

import "core:fmt"
import "core:time"
import "core:os"
import "gui"
import "draw"
import "core:mem"
import "odinlib:util"
import "core:log"
import "base:intrinsics"

WINDOW_TITLE := "SIM6502"
WINDOW_SIZE := util.vec2{600, 600}

app_context: ^App_Context
vec2 :: util.vec2

App_Init :: struct {
    handle_platform_command: proc(_: util.Platform_Command),
    dots_per_inch: i32,
    window_size: vec2,
    graphics_backend: util.Renderer_Backend,
}

App_Update :: struct {
    graphics_backend: ^util.Renderer_Backend,
}

App_Context :: struct {
    font: draw.Font,
    dots_per_inch: i32,
    gui_context: gui.Context,
    draw_context: draw.Draw_Context,
    handle_platform_command: proc(_: util.Platform_Command),
    // renderers: [util.Graphics_Backend]Renderer,
    running, auto_add: bool,
    window_size: vec2,
}

init :: proc(I: App_Init) {
    app_context = new(App_Context)
    using app_context
    // TODO: validate draw_context
    draw.init(&draw_context)
    font = draw.create_font("resources/consola.ttf", 30)
    handle_platform_command = I.handle_platform_command 
    handle_platform_command({
        type=.Rename_Window,
        title=WINDOW_TITLE,
    })
    handle_platform_command({
        type=.Resize_Window,
        size=WINDOW_SIZE,
    })
    dots_per_inch = I.dots_per_inch
    window_size = I.window_size
    gui_context.dots_per_inch = dots_per_inch
    gui_context.draw_context = &draw_context
    gui_context.handle_platform_command = handle_platform_command 
    gui.init(&gui_context, I.window_size)
    // gui.create_control(&gui_context, "first", gui.text_box(&gui_context, "Hello"))
    // gui.create_control(&gui_context, "reg_sp", gui.text_box(&gui_context, "SP", 0xffff))
    // button := gui.create_control(&gui_context, "button", gui.button(&gui_context, "Click Me!"))
    current_directory_fd, open_err := os.open(os.get_current_directory())
    dir_list, read_err := os.read_dir(current_directory_fd, 64)
    if read_err != nil {
        log.fatal("Could not list current working directory")
    }
    os.close(current_directory_fd)

    // gui.create_control(&gui_context, "parent", gui.list_item(&gui_context, ".."))
    for entry, i in dir_list {
        buf: [8]u8
        log.debug(entry.name)
        // name := fmt.bprintf(buf[:], "list%v", i)
        // gui.create_control(
        //     &gui_context,
        //     name,
        //     gui.list_item(&gui_context, entry.name)
        // )
    }
    text_box := gui.create_control(&gui_context, "txt", gui.text_box(&font))
    slider := gui.create_control(&gui_context, "slid", gui.slider(0, 20, 3))
    // button1 := gui.create_control(&gui_context, "btn1", gui.button("BUTTON 1"))
    // button2 := gui.create_control(&gui_context, "btn2", gui.button("BUTTON 2"))
    // button3 := gui.create_control(&gui_context, "btn3", gui.button("BUTTON 3"))
    min_size := util.dip_to_px(96*3, dots_per_inch)
    gui_context = gui_context
    running = true
    handle_platform_command({type=.Set_Window_Min_Size, size=util.vec2{min_size, min_size}})
}

@(private)
shutdown :: proc() {
    log.debug("SHUTDOWN")
}

update :: proc(_: App_Update) -> bool {
    using app_context
    defer free_all(context.temp_allocator)
    interval :: 500 * time.Millisecond
    if !app_context.running {
        shutdown()
        return false
    }
    @(static) last_tick: time.Tick
    @(static) button_count := 4
    if auto_add && time.tick_since(last_tick) >= interval {
        button_name_buf: [8]u8
        button_name := fmt.bprintf(button_name_buf[:], "btn%v", button_count)
        button_label_buf: [16]u8
        button_label := fmt.bprintf(button_label_buf[:], "NEW BTN %v", button_count)
        gui.create_control(&gui_context, button_name, gui.button(button_label, &font))
        button_count += 1
        handle_platform_command(util.Platform_Command {
            title=button_label,
            type=.Rename_Window,
        })
        last_tick = time.tick_now()
    }
    for event in gui.next_event(&gui_context) {
        switch {
        case event.control.type == .Button:
            log.debug("Button pressed")
        case gui.name(event.control) == "txt":
            log.debug("Text box changed")
        case gui.name(event.control) == "slid": 
            log.debugf("Slider moved to %v", event.slider)
        }
    }
    render()
    return true
}

render :: proc() {
    using app_context
    // TODO: Move to renderer
    draw.begin(&draw_context, app_context.window_size)
    defer draw.end(&draw_context)
    draw.push_command(&draw_context, draw.Clear{color=draw.color_white})
    gui.render(&gui_context)
    text_buf: [32]u8
    text := fmt.bprintf(text_buf[:], "Auto add: %v", "ON" if auto_add else "OFF")
    draw.push_command(
        &draw_context, 
        draw.Draw_Text {
            rect=gui.rect_to_f(util.size_to_rect(
                vec2 {
                    draw.get_text_width(&font, text),
                    draw.get_text_height(&font),
                })),
            font=&font,
            text=text,
            color=draw.color_black,
        }
    )
}

handle_event :: proc(event: util.Window_Event) {
    #partial switch event.type {
    case .Window_Resize:
        // draw.resize(&ctx.draw_context, event.vec2)
        app_context.window_size = event.vec2
    case .Window_Close:
        app_context.running = false
    case .Key:
        if event_was_key_pressed(event, util.KEY_SPACE) {
            app_context.auto_add = !app_context.auto_add
        } else if event_was_key_released(event, util.KEY_ESCAPE) {
            app_context.running = false
            log.debug("Should be done")
        } else {
            log.debug(event.key)
        }
    }
    gui.handle_event(&app_context.gui_context, event)
}

event_was_key_pressed :: proc(event: util.Window_Event, keycode: u32) -> bool {
    return event.key.pressed && !event.key.repeated && event.key.keycode == keycode 
}

event_was_key_released :: proc(event: util.Window_Event, keycode: u32) -> bool {
    return !event.key.pressed && event.key.keycode == keycode 
}

