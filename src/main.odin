package src

import "core:fmt"
import "core:time"
import "core:os"
import "gui"
import "draw"
import "core:mem"
import "odinlib:util"
import sa "core:container/small_array"
import "core:log"
import "base:intrinsics"

WINDOW_TITLE := "SIM6502"
WINDOW_SIZE := util.vec2{600, 600}
PLATFORM_BACKEND :: #config(BACKEND, "native")

app: ^App_Context
vec2 :: util.vec2

App_Init :: struct {
    handle_platform_command: proc(_: util.Platform_Command),
    dots_per_inch: i32,
    window_size: vec2,
}

App_Update :: struct {
    renderers: []^draw.Renderer,
    renderer_index: ^int,
}

App_Context :: struct {
    font: draw.Font,
    dots_per_inch: i32,
    gui_context: gui.Context,
    gui_stack: sa.Small_Array(3, gui.Context),
    renderers: []^draw.Renderer,
    renderer_index: ^int,
    draw_context: draw.Draw_Context,
    handle_platform_command: proc(_: util.Platform_Command),
    // renderers: [util.Graphics_Backend]Renderer,
    running, auto_add: bool,
    window_size: vec2,
    mouse_position: vec2,
}

@(export, link_name="app_init")
init :: proc(I: App_Init) {
    app = new(App_Context)
    // TODO: validate draw_context
    draw.init(&app.draw_context)
    app.font = draw.create_font("resources/consola.ttf", 30)
    app.handle_platform_command = I.handle_platform_command 
    app.handle_platform_command({
        type=.Rename_Window,
        title=WINDOW_TITLE,
    })
    app.handle_platform_command({
        type=.Resize_Window,
        size=WINDOW_SIZE,
    })
    app.dots_per_inch = I.dots_per_inch
    app.window_size = I.window_size
    app.gui_context.dots_per_inch = app.dots_per_inch
    app.gui_context.draw_context = &app.draw_context
    app.gui_context.handle_platform_command = app.handle_platform_command 
    gui.init(&app.gui_context, I.window_size)
    // gui.create_control(&gui_context, "first", gui.text_box(&gui_context, "Hello"))
    // gui.create_control(&gui_context, "reg_sp", gui.text_box(&gui_context, "SP", 0xffff))
    // button := gui.create_control(&gui_context, "button", gui.button(&gui_context, "Click Me!"))
    dir_path, _ := os.get_working_directory(context.temp_allocator)
    current_directory_fd, open_err := os.open(dir_path)
    dir_list, read_err := os.read_dir(current_directory_fd, 64, context.temp_allocator)
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
    text_box := gui.create_control(&app.gui_context, "txt", gui.text_box(&app.font))
    slider := gui.create_control(&app.gui_context, "slid", gui.slider(0, 5, 3))
    // button1 := gui.create_control(&gui_context, "btn1", gui.button("BUTTON 1"))
    // button2 := gui.create_control(&gui_context, "btn2", gui.button("BUTTON 2"))
    // button3 := gui.create_control(&gui_context, "btn3", gui.button("BUTTON 3"))
    min_size := util.dip_to_px(96*3, app.dots_per_inch)
    app.gui_context = app.gui_context
    app.running = true
    app.handle_platform_command({type=.Set_Window_Min_Size, size=util.vec2{min_size, min_size}})
}

@(private)
shutdown :: proc() {
    log.debug("SHUTDOWN")
}

@(export, link_name="app_update")
update :: proc(U: App_Update) -> bool {
    defer free_all(context.temp_allocator)
    interval :: 500 * time.Millisecond
    if !app.running {
        shutdown()
        return false
    }
    app.renderers, app.renderer_index = U.renderers, U.renderer_index
    @(static) last_tick: time.Tick
    @(static) button_count := 4
    if app.auto_add && time.tick_since(last_tick) >= interval {
        button_name_buf: [8]u8
        button_name := fmt.bprintf(button_name_buf[:], "btn%v", button_count)
        button_label_buf: [16]u8
        button_label := fmt.bprintf(button_label_buf[:], "NEW BTN %v", button_count)
        gui.create_control(&app.gui_context, button_name, gui.button(button_label, &app.font))
        button_count += 1
        app.handle_platform_command(util.Platform_Command {
            title=button_label,
            type=.Rename_Window,
        })
        last_tick = time.tick_now()
    }
    for event in gui.next_event(&app.gui_context) {
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

@(export, link_name="app_render")
render :: proc() {
    // TODO: Move to renderer
    if app.renderer_index == nil do return
    draw.begin(&app.draw_context)
    color: util.Color4f
    color.r = (cast(f32)app.mouse_position.x / cast(f32)app.window_size.x)
    color.g = (cast(f32)app.mouse_position.y / cast(f32)app.window_size.y)
    draw.push_command(&app.draw_context, draw.Clear{color=color})
    gui.render(&app.gui_context)
    text_buf: [32]u8
    text := fmt.bprintf(text_buf[:], "Auto add: %v", "ON" if app.auto_add else "OFF")
    draw.push_command(
        &app.draw_context, 
        draw.Draw_Text {
            rect=gui.rect_to_f(util.size_to_rect(
                vec2 {
                    draw.get_text_width(&app.font, text),
                    draw.get_text_height(&app.font),
                })),
            font=&app.font,
            text=text,
            color=draw.color_black,
        }
    )
    draw.end(&app.draw_context, app.renderers[app.renderer_index^], app.window_size)
}

@(export, link_name="app_handle_event")
handle_event :: proc(event: util.Window_Event) {
    #partial switch event.type {
    case .Window_Resize:
        // draw.resize(&ctx.draw_context, event.vec2)
        app.renderers[app.renderer_index^]->resize(event.vec2.x, event.vec2.y)
        app.window_size = event.vec2
    case .Window_Close:
        app.running = false
    case .Mouse_Move:
        app.mouse_position = event.vec2
    case .Key:
        if event_was_key_pressed(event, util.KEY_SPACE) {
            app.auto_add = !app.auto_add
        } else if event_was_key_released(event, util.KEY_ESCAPE) {
            app.running = false
            log.debug("Should be done")
        } else {
            log.debug(event.key)
        }
    }
    gui.handle_event(&app.gui_context, event)
}

event_was_key_pressed :: proc(event: util.Window_Event, keycode: u32) -> bool {
    return event.key.pressed && !event.key.repeated && event.key.keycode == keycode 
}

event_was_key_released :: proc(event: util.Window_Event, keycode: u32) -> bool {
    return !event.key.pressed && event.key.keycode == keycode 
}

