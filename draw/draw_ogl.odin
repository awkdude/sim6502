package draw

import "odinlib:util"
import gl "vendor:OpenGL"
import sa "core:container/small_array"

OpenGL_Context :: struct {
    command_buffer: sa.Small_Array(1024, Command),
}

new_draw_context_opengl :: proc(allocator := context.allocator) -> Draw_Context {
// {{{
    ogl_context := new(OpenGL_Context, allocator)
    return Draw_Context {
        vtable=new_clone(OpenGL_VTable, allocator),
        data=ogl_context,
    }
// }}}
}

ogl_push_clip_rect :: proc(draw_context: ^Draw_Context, rect: Rect) {
	
}

ogl_pop_clip_rect :: proc(draw_context: ^Draw_Context) {
	
}

ogl_begin_frame :: proc(draw_context: ^Draw_Context) {
	
}

ogl_end_frame :: proc(draw_context: ^Draw_Context) {
	
}

ogl_get_render_target_dpi :: proc(draw_context: ^Draw_Context) -> i32 {
	return 0
}

ogl_get_render_target_size :: proc(draw_context: ^Draw_Context) -> vec2 {
    return {}
}

ogl_measure_string :: proc(draw_context: ^Draw_Context, font: rawptr, text: string) -> vec2 {
	return {}
}

ogl_push_command :: proc(draw_context: ^Draw_Context, command: Command) {
    ogl_context := cast(^OpenGL_Context)draw_context.data
    sa.append(&ogl_context.command_buffer, command)
}

ogl_resize :: proc(draw_context: ^Draw_Context, size: vec2) {
	gl.Viewport(0, 0, size.x, size.y)
}

ogl_create_font :: proc(
    draw_context: ^Draw_Context,
    name: string,
    size_dip: f32,
    type: Font_Resource_Type = .System
) -> Font 
{
	
}
ogl_get_char_rect :: proc(
    draw_context: ^Draw_Context,
    font: Font,
    text: string,
    char_index: int) -> (Rect, bool) 
{
	
}

OpenGL_VTable := Draw_Context_VTable {

}
