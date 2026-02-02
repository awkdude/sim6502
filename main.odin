package main

import "core:fmt"
import "core:time"
import "core:os"
import "gui"
import "draw"
import "odinlib:util"
import "core:log"
import "base:intrinsics"

PRE_INIT_WINDOW_TITLE := "SIM6502"
PRE_INIT_WINDOW_SIZE := util.vec2{600, 600}

app_context: ^App_Context

App_Context :: struct {
    font: rawptr,
    gui_context: gui.Context,
    draw_context: ^draw.Draw_Context,
    handle_platform_command: proc(_: util.Platform_Command),
    auto_add: bool,
}

App_Init :: struct {
    draw_context: ^draw.Draw_Context,
    handle_platform_command: proc(_: util.Platform_Command),
}

app_init :: proc(I: App_Init) {
    app_context = new(App_Context)
    // TODO: validate draw_context
    app_context.font = I.draw_context->create_font("consolas", 30)
    app_context.gui_context.draw_context = I.draw_context
    app_context.gui_context.handle_platform_command = handle_platform_command 
    gui_context: gui.Context
    gui.context_init(&gui_context)
    // gui.create_control(&gui_context, "first", gui.text_box(&gui_context, "Hello"))
    // gui.create_control(&gui_context, "reg_sp", gui.text_box(&gui_context, "SP", 0xffff))
    // button := gui.create_control(&gui_context, "button", gui.button(&gui_context, "Click Me!"))
    current_directory_fd, open_err := os.open(os.get_current_directory())
    
    if open_err != nil {
        log.fatal("Could not open current working directory")
    }
    dir_list, read_err := os.read_dir(current_directory_fd, 64)
    if read_err != nil {
        log.fatal("Could not list current working directory")
    }
    os.close(current_directory_fd)
    // gui.create_control(&gui_context, "parent", gui.list_item(&gui_context, ".."))
    // for entry, i in dir_list {
    //     buf: [8]u8
    //     name := fmt.bprintf(buf[:], "list%v", i)
    //     gui.create_control(
    //         &gui_context,
    //         name,
    //         gui.list_item(&gui_context, entry.name)
    //     )
    // }
    text_box := gui.create_control(&gui_context, "txt", gui.text_box(app_context.font))
    slider := gui.create_control(&gui_context, "slid", gui.slider(0, 10, 3))
    // button1 := gui.create_control(&gui_context, "btn1", gui.button("BUTTON 1"))
    // button2 := gui.create_control(&gui_context, "btn2", gui.button("BUTTON 2"))
    // button3 := gui.create_control(&gui_context, "btn3", gui.button("BUTTON 3"))
    min_size := util.dip_to_px(96*3, I.draw_context->get_render_target_dpi())
    app_context.gui_context = gui_context
    app_context.draw_context = I.draw_context
    handle_platform_command({type=.Set_Window_Min_Size, size=util.vec2{min_size, min_size}})
}

app_update :: proc() {
    using app_context
    free_all(context.temp_allocator)
    interval :: 500 * time.Millisecond
    @(static) last_tick: time.Tick
    @(static) button_count := 4
    if auto_add && time.tick_since(last_tick) >= interval {
        button_name_buf: [8]u8
        button_name := fmt.bprintf(button_name_buf[:], "btn%v", button_count)
        button_label_buf: [16]u8
        button_label := fmt.bprintf(button_label_buf[:], "NEW BTN %v", button_count)
        gui.create_control(&gui_context, button_name, gui.button(button_label, font))
        button_count += 1
        handle_platform_command(util.Platform_Command {
            title=button_label,
            type=.Rename_Window,
        })
        last_tick = time.tick_now()
    }
    for event in gui.next_event(&gui_context) {
        if event.control.type == .Button {
            log.debug("Button pressed")
        } else if gui.name(event.control) == "txt" {
            log.debug("Text box changed")
        } else if gui.name(event.control) == "slid" {
            log.debugf("Slider moved to %v", event.slider)
        }
    }
    app_render()
}

app_render :: proc() {
    using app_context
    draw_context->begin_frame()
    gui.context_render(&gui_context)
    text_buf: [32]u8
    text := fmt.bprintf(text_buf[:], "Auto add: %v", "ON" if auto_add else "OFF")
    draw_context->push_command(
        draw.Draw_Text {
            rect=util.size_to_rect(draw_context->measure_string(font, text)),
            font=font,
            text=text,
            color=draw.color_black,
        }
    )
    draw_context->end_frame()
}

app_handle_event :: proc( event: util.Window_Event) {
    using app_context
    #partial switch event.type {
    case .Window_Resize:
        draw_context->resize(event.vec2)
    case .Window_Close:
        handle_platform_command(util.Platform_Command {type=.Quit})
    case .Key:
        if event.key.keycode == ' ' && event.key.pressed && !event.key.repeated {
            auto_add = !auto_add
        } else if event.key.keycode == util.KEY_ESCAPE && !event.key.pressed {
            handle_platform_command(util.Platform_Command {type=.Quit})
        }
    }
    gui.context_handle_event(&gui_context, event)
}
