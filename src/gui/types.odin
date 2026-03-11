package gui

import "odinlib:util"

Control_Type :: enum {
    Container,
    Label,
    Text_Box,
    Button,
    Slider,
    Group_Box,
}

default_render :: proc(ctx: ^Context, control: ^Control) {}
default_handle_event :: proc(
    ctx: ^Context,
    control: ^Control,
    event: util.Window_Event) 
{
}

allowed_child_types := #partial [Control_Type]bit_set[Control_Type] {
    .Container = ~{},
    .Button = {.Label}, 
}

Control_Proc_Type :: #type proc(ctx: ^Context, control: ^Control)
Handle_Event_Proc_Type :: #type proc(_: ^Context, _: ^Control, _: util.Window_Event)

handle_event_proc_table := [Control_Type]Handle_Event_Proc_Type {
    .Container = container_handle_event,
    .Text_Box = text_box_handle_event,
    .Button = button_handle_event,
    .Label = default_handle_event,
    .Slider = slider_handle_event,
    .Group_Box = default_handle_event,
}

render_proc_table := [Control_Type]Control_Proc_Type {
    .Container = container_render,
    .Text_Box = text_box_render,
    .Button = button_render,
    .Label = label_render,
    .Slider = slider_render,
    .Group_Box = default_render,
} 

deactive_table := #partial [Control_Type]bit_set[Deactive_Flag] {
    .Button = {.Mouse_Outside},
    .Slider = {.Mouse_Release},
    .Text_Box = {.Key_Escape, .Mouse_Press_Outside},
}

mouse_cursor_on_hover := #partial [Control_Type]util.Mouse_Cursor_Type {
    .Text_Box = .IBeam,
    .Button = .Hand,
}
