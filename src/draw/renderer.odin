package draw

import sa "core:container/small_array"
import "core:slice"
import "core:log"
import "odinlib:util"
import gl "vendor:OpenGL"
import "core:math/linalg"

Color4f :: util.Color4f
mat4 ::  util.mat4
vec3f :: util.vec3f

R_Vertex :: struct {
    position: vec3f, 
    color: Color4f,
    tex_coords: vec2f,
    tex_index: f32,
}

MAX_NUM_VERTICES :: 18 * 1024
MAX_NUM_TEXTURE_UNITS :: 32


// TODO: prepend with OGL_
Renderer :: struct {
    vao, vbo: u32,
    source_shader: util.Source_Shader,
    textures: sa.Small_Array(MAX_NUM_TEXTURE_UNITS, u32),
    projection_mat: mat4,
    depth: f32,
    vertices: sa.Small_Array(MAX_NUM_VERTICES, R_Vertex),
}

BAD_TEX_ID: u32 : 4096 

get_white_tex_id :: proc() -> u32 {
// {{{
    @(static) white_tex_id: u32 = BAD_TEX_ID
    if white_tex_id != BAD_TEX_ID {
        return white_tex_id
    } 
    white_tex_id = util.create_texture_from_pixmap(util.Pixmap{
        pixels=raw_data([]u8{255, 255, 255, 255}),
        w=2,
        h=2,
        bytes_per_pixel=1,
    })
    return white_tex_id
// }}}
}

renderer_init :: proc(renderer: ^Renderer) -> bool {
// {{{
    renderer^ = {}
    gl.GenVertexArrays(1, &renderer.vao)
    gl.BindVertexArray(renderer.vao)
    gl.GenBuffers(1, &renderer.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(R_Vertex) * sa.cap(renderer.vertices), 
        nil, 
        gl.DYNAMIC_DRAW
    )
    gl.EnableVertexAttribArray(0)
    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE, 
        size_of(R_Vertex), 
        offset_of(R_Vertex, position)
    )
    gl.VertexAttribPointer(
        1,
        4,
        gl.FLOAT, 
        gl.FALSE, 
        size_of(R_Vertex), 
        offset_of(R_Vertex, color)
    )
    gl.VertexAttribPointer(
        2, 
        2,
        gl.FLOAT,
        gl.FALSE, 
        size_of(R_Vertex), 
        offset_of(R_Vertex, tex_coords)
    )
    gl.VertexAttribPointer(
        3,
        1,
        gl.FLOAT,
        gl.FALSE,
        size_of(R_Vertex), 
        offset_of(R_Vertex, tex_index)
    )
    renderer.depth = 0.0
    renderer.source_shader = util.Source_Shader {
        vertex_source_path = "resources/text_shader.vert",
        fragment_source_path = "resources/text_shader.frag",
        use_2d_default=true,
        on_update_proc=proc(program: u32, _: rawptr) {
            tex_indices: [MAX_NUM_TEXTURE_UNITS]i32
            for i in 0..<MAX_NUM_TEXTURE_UNITS {
                tex_indices[i] = cast(i32)i
            }
            util.shader_uniform(program, "u_textures", tex_indices[:])
        }
    }
    util.source_shader_update(&renderer.source_shader)
    gl.UseProgram(renderer.source_shader.program)
    gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    gl.BindVertexArray(0)
    return true
// }}}
}

renderer_begin_frame :: proc(renderer: ^Renderer, u_proj: mat4) {
// {{{
    sa.clear(&renderer.vertices)
    sa.clear(&renderer.textures)
    gl.Enable(gl.BLEND)
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    // gl.Disable(gl.DEPTH_TEST)
    // gl.DepthFunc(gl.LESS)
    gl.BindVertexArray(renderer.vao)
    gl.UseProgram(renderer.source_shader.program)
    renderer.depth = 0.0
    renderer.projection_mat = u_proj
    util.shader_uniform(
        renderer.source_shader.program,
        "u_proj", 
        &renderer.projection_mat 
    )
// }}}
}

renderer_set_viewport :: proc(renderer: ^Renderer, render_size: vec2) {
    gl.Viewport(0, 0, render_size.x, render_size.y)
}

renderer_clear_color :: proc(renderer: ^Renderer, color: Color4f) {
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    gl.ClearColor(color.r, color.g, color.b, color.a)
}

renderer_end_frame :: proc(renderer: ^Renderer) {
// {{{
    gl.Disable(gl.DEPTH_TEST)
    defer gl.Enable(gl.DEPTH_TEST)
    gl.Enable(gl.SCISSOR_TEST)
    defer gl.Disable(gl.SCISSOR_TEST)
    gl.UseProgram(renderer.source_shader.program)
    for tex_id, i in sa.slice(&renderer.textures) {
        gl.ActiveTexture(cast(u32)(gl.TEXTURE0 + i))
        gl.BindTexture(gl.TEXTURE_2D, tex_id)
    }
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(R_Vertex) * sa.cap(renderer.vertices), 
        nil, 
        gl.DYNAMIC_DRAW
    )
    gl.BufferSubData(
        gl.ARRAY_BUFFER, 
        0,
        slice.size(sa.slice(&renderer.vertices)), 
        sa.get_ptr(&renderer.vertices, 0)
    )
    gl.DrawArrays(gl.TRIANGLES, 0, cast(i32)sa.len(renderer.vertices))
    // gl.Enable(gl.DEPTH_TEST)
    // gl.DepthFunc(gl.LESS)
// }}}
}

renderer_flush :: #force_inline proc(renderer: ^Renderer) {
    renderer_end_frame(renderer)
    renderer_begin_frame(renderer, renderer.projection_mat)
}


renderer_set_clip_rect :: proc(renderer: ^Renderer, clip_rect: Rect, loc := #caller_location) {
    assert(clip_rect.x >= 0, loc=loc)
    assert(clip_rect.y >= 0, loc=loc)
    assert(clip_rect.w >= 0, loc=loc)
    assert(clip_rect.h >= 0, loc=loc)
    // gl.Scissor(clip_rect.x, clip_rect.y, clip_rect.w, clip_rect.h)
}

renderer_push_quad_textured :: proc(
    renderer: ^Renderer,
    rect: Rectf,
    color: Color4f,
    tex_id: u32,
    st: [2]vec2f = {{0.0, 0.0}, {1.0, 1.0}},
)
{ 
// {{{
    if sa.space(renderer.vertices) < 6 {
        renderer_flush(renderer)
    }
    tex_index := texture_index_from_id(renderer, tex_id)
    x := rect.x
    y := rect.y
    w := rect.w
    h := rect.h
    sa.push( 
    // {{{
       &renderer.vertices,
        R_Vertex{
            position={x, y + h, renderer.depth},
            tex_coords={st[0].x, st[1].y},
            color=color,
            tex_index=tex_index,
        },
        R_Vertex{
            position={x + w, y + h, renderer.depth},
            tex_coords={st[1].x, st[1].y},
            color=color,
            tex_index=tex_index,
        },
        R_Vertex{
            position={x + w, y, renderer.depth},
            tex_coords={st[1].x, st[0].y},
            color=color,
            tex_index=tex_index,
        },
        R_Vertex{
            position={x, y + h, renderer.depth},
            tex_coords={st[0].x, st[1].y},
            color=color,
            tex_index=tex_index,
        },
        R_Vertex{
            position={x + w, y, renderer.depth},
            tex_coords={st[1].x, st[0].y},
            color=color,
            tex_index=tex_index,
        },
        R_Vertex{
            position={x, y, renderer.depth},
            tex_coords={st[0].x, st[0].y},
            color=color,
            tex_index=tex_index,
        },
    // }}}
    )
// }}} 
}

renderer_push_quad_color :: proc(renderer: ^Renderer, rect: Rectf, color: Color4f) {
    renderer_push_quad_textured(renderer, rect, color, get_white_tex_id()) 
}

renderer_push_outline_rect :: proc(
    renderer: ^Renderer,
    rect: Rectf,
    color: Color4f,
    line_width: f32 = 3.0,
) 
{
// {{{
    // Top {{{
    renderer_push_quad(
        renderer,
        Rectf {
            rect.x-line_width,
            rect.y-line_width,
            rect.w+line_width,
            line_width,
        },
        color,
    )
    // }}}
    // Bottom {{{
    renderer_push_quad(
        renderer,
        Rectf {
            rect.x-line_width,
            rect.y+rect.h,
            rect.w+line_width*2,
            line_width,
        },
        color,
    )
    // }}}
    // Left {{{
    renderer_push_quad(
        renderer,
        Rectf {
            rect.x-line_width,
            rect.y,
            line_width,
            rect.h,
        },
        color,
    )
    // }}}
    // Right {{{
    renderer_push_quad(
        renderer,
        Rectf {
            rect.x+rect.w,
            rect.y-line_width,
            line_width,
            rect.h+line_width,
        },
        color,
    )
    // }}}
//}}} 
}

renderer_push_quad :: proc {
    renderer_push_quad_color, 
    renderer_push_quad_textured, 
}

@(private)
texture_index_from_id :: #force_inline proc(renderer: ^Renderer, tex_id: u32) -> f32 {
// {{{
    tex_index: u32 = BAD_TEX_ID
    if idx, found := slice.linear_search(sa.slice(&renderer.textures), tex_id); found {
        tex_index = cast(u32)idx
    } else {
        if !sa.push(&renderer.textures, tex_id) {
            renderer_flush(renderer)
            sa.push(&renderer.textures, tex_id)
        }
        tex_index = cast(u32)(sa.len(renderer.textures) - 1)
    }
    assert(tex_index != BAD_TEX_ID)
    return cast(f32)tex_index
// }}}
}

renderer_push_tri :: proc(
    renderer: ^Renderer,
    verts: [3]vec2f,
    color: Color4f) 
{
// {{{
    tex_index := texture_index_from_id(renderer, get_white_tex_id())
    if sa.space(renderer.vertices) < 3 {
        renderer_flush(renderer)
    }
    sa.push( 
        &renderer.vertices,
        R_Vertex{
            position={verts[0].x, verts[0].y, 0.0},
            tex_coords={0.0, 0.0},
            color=color,
            tex_index=cast(f32)tex_index,
        },
        R_Vertex{
            position={verts[1].x, verts[1].y, 0.0},
            tex_coords={0.0, 0.0},
            color=color,
            tex_index=cast(f32)tex_index,
        },
        R_Vertex{
            position={verts[2].x, verts[2].y, 0.0},
            tex_coords={0.0, 0.0},
            color=color,
            tex_index=cast(f32)tex_index,
        },
    )
// }}}
}

renderer_push_tri_ndc :: proc(
    renderer: ^Renderer,
    verts: [3]vec2f,
    color: Color4f,
    rect: Rectf) 
{
// {{{
    renderer_push_tri(
        renderer,
        {
            map_point(verts[0], rect),
            map_point(verts[1], rect),
            map_point(verts[2], rect),
        },
        color,
    )
// }}}
}

renderer_push_line :: proc(
    renderer: ^Renderer,
    start, end: vec2f,
    line_width: f32,
    color: Color4f) 
{
// {{{
    direction := linalg.normalize0(end - start)
    offset := vec2f{-direction.y, direction.x} * (line_width / 2)
    renderer_push_tri(
        renderer,
        {
            start + offset,
            start - offset,
            end - offset,
        },
        color
    )
    renderer_push_tri(
        renderer,
        {
            end - offset,
            end + offset,
            start + offset,
        },
        color
    )
// }}}
}

renderer_push_line_ndc :: proc(
    renderer: ^Renderer,
    start, end: vec2f,
    line_width: f32,
    color: Color4f,
    rect: Rectf
) 
{
    renderer_push_line(
        renderer,
        map_point(start, rect),
        map_point(end, rect),
        line_width,
        color,
    )
}


// color_white   :: Color4f{1.000, 1.000, 1.000, 1.0}
// color_black   :: Color4f{0.000, 0.000, 0.000, 1.0}
// color_gray    :: Color4f{0.500, 0.500, 0.500, 1.0}
// color_red     :: Color4f{1.000, 0.000, 0.000, 1.0}
// color_green   :: Color4f{0.000, 1.000, 0.000, 1.0}
// color_blue    :: Color4f{0.000, 0.000, 1.000, 1.0}
// color_magenta :: Color4f{1.000, 0.000, 1.000, 1.0}
// color_yellow  :: Color4f{1.000, 1.000, 0.000, 1.0}
// color_cyan    :: Color4f{0.000, 1.000, 1.000, 1.0}
// color_coral   :: Color4f{1.000, 0.500, 0.310, 1.0}
