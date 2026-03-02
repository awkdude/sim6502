package draw

import "odinlib:util"

Renderer_SW :: struct {
    using _: Renderer,
    clear_color: util.Color4f,
    target_pixmap: util.Pixmap,
}

sw_renderer_init :: proc(renderer: ^Renderer_SW, target: util.Pixmap) -> bool {
    renderer^ = {
        target_pixmap = target,
        name="Software",
        begin_frame=sw_begin_frame,
        end_frame=sw_end_frame,
        set_clear_color=sw_clear_color,
        set_viewport=sw_set_viewport,
        set_clip_rect=sw_set_clip_rect,
        push_quad_textured=sw_push_quad_textured,
        push_quad_color=sw_push_quad_color,
    }
    return true
}

sw_begin_frame :: proc(renderer: ^Renderer, u_proj: mat4) {
    sw_renderer := cast(^Renderer_SW)renderer
    _fill(sw_renderer.target_pixmap, sw_renderer.clear_color)
}

sw_set_viewport :: proc(renderer: ^Renderer, render_size: vec2) {
}

sw_clear_color :: proc(renderer: ^Renderer, color: Color4f) {
    (cast(^Renderer_SW)renderer).clear_color = color
}

sw_end_frame :: proc(renderer: ^Renderer) {
    
}

sw_flush :: #force_inline proc(renderer: ^Renderer) {
    renderer := cast(^Renderer_OGL)renderer
    sw_end_frame(renderer)
    sw_begin_frame(renderer, renderer.projection_mat)
}


sw_set_clip_rect :: proc(renderer: ^Renderer, clip_rect: Rect, loc := #caller_location) {
    when CHECK_CLIP {
        assert(clip_rect.x >= 0, loc=loc)
        assert(clip_rect.y >= 0, loc=loc)
        assert(clip_rect.w >= 0, loc=loc)
        assert(clip_rect.h >= 0, loc=loc)
    }
    // gl.Scissor(clip_rect.x, clip_rect.y, clip_rect.w, clip_rect.h)
}

sw_push_quad_textured :: proc(
    renderer: ^Renderer,
    rect: Rectf,
    color: Color4f,
    tex_id: u32,
    st: [2]vec2f = {{0.0, 0.0}, {1.0, 1.0}},
)
{ 
}

sw_push_quad_color :: proc(renderer: ^Renderer, rect: Rectf, color: Color4f) {
    // sw_push_quad_textured(renderer, rect, color, get_white_tex_id()) 
}
