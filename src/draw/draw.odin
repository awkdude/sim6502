package draw

import "core:mem"
import "core:fmt"
import "core:math"
import "base:runtime"
import "core:strings"
import "core:math/bits"
import "core:os"
import "core:log"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
import "odinlib:util"
import "core:math/linalg"
import sa "core:container/small_array"

vec2   :: util.vec2
Rect   :: util.Rect
BBox :: util.BBox
Color_f  :: util.Color_f
Color_4b :: util.Color4b
Color4b :: Color_4b

// TODO: Maybe rename Draw_Context to Render_Group, Command_Buffer, etc. 

Texture :: uintptr

Vertex :: struct { 
    position: vec2f,
    color: Color4f,
    uv: vec2f,
}

Font :: struct {
    font_data: []u8,
    packedchar_array: [96]stbtt.packedchar,
    font_info: stbtt.fontinfo,
    atlas_pixmap: util.Pixmap,
    atlas_tex_id: Texture,
    font_path: string,
    font_size_px: i32,
    ok: bool
}

Font_Resource_Type :: enum {
    System,
    File,
}

Renderer :: struct {
    name: string,
    begin_frame: proc(this: ^Renderer, u_proj: mat4),
    end_frame: proc(this: ^Renderer),
    set_clear_color: proc(this: ^Renderer, color: Color4f),
    set_viewport: proc(this: ^Renderer, rect: Rect),
    set_clip_rect: proc(this: ^Renderer, rect: Rect, loc: runtime.Source_Code_Location),
    create_texture_from_pixmap: proc(this: ^Renderer, pixmap: Pixmap) -> (Texture, bool),
    // TODO: Delete
    create_texture_from_path: proc(this: ^Renderer, path: string) -> (Texture, bool),
    push_quad_textured: proc(
        this: ^Renderer,
        rect: Rectf,
        color: Color4f,
        tex_id: Texture,
        st: [2]vec2f = {{0.0, 0.0}, {1.0, 1.0}},
    ),
    push_quad_color: proc(this: ^Renderer, rect: Rectf, color: Color4f),
    // push_tri: proc(this: ^Renderer, vertices: [3]Vertex),
    push_tri: proc(this: ^Renderer, vertices: [3]vec2f, color: Color4f),
    resize: proc(this: ^Renderer, size: vec2),
    present: proc(this: ^Renderer),
}

dummy_renderer :: proc() -> Renderer {
    return {
        name="?",
        begin_frame=proc(this: ^Renderer, u_proj: mat4) {},
        end_frame=proc(this: ^Renderer) {},
        set_clear_color=proc(this: ^Renderer, color: Color4f) {},
        set_viewport=proc(this: ^Renderer, rect: Rect) {},
        set_clip_rect=proc(this: ^Renderer, rect: Rect, loc: runtime.Source_Code_Location) {},
        create_texture_from_pixmap=proc(this: ^Renderer, pixmap: Pixmap) -> (Texture, bool){
            return 0, false
        },
        push_quad_textured=proc(
            this: ^Renderer,
            rect: Rectf,
            color: Color4f,
            tex_id: Texture,
            st: [2]vec2f = {{0.0, 0.0}, {1.0, 1.0}},
        ) {},
        push_quad_color=proc(this: ^Renderer, rect: Rectf, color: Color4f) {},
        // push_tri=proc(this: ^Renderer, vertices: [3]Vertex) {},
        push_tri=proc(this: ^Renderer, vertices: [3]vec2f, color: Color4f) {},
        resize=proc(this: ^Renderer, size: vec2) {},
        present=proc(this: ^Renderer) {},
    }
}


create_font :: proc(
    font_path: string,
    font_size_px: i32,
    renderer: ^Renderer,
    allocator := context.allocator) -> Font 
{
    font: Font
    err: os.Error
    font.font_data, err = os.read_entire_file_from_path(font_path, allocator)
    assert(err == nil, "Font load error")
    assert(stbtt.InitFont(&font.font_info, raw_data(font.font_data[:]), 0) == true)
    font.atlas_pixmap = util.make_pixmap(512, 512, 1)
    pack_context: stbtt.pack_context
    stbtt.PackBegin(
        &pack_context,
        cast([^]u8)font.atlas_pixmap.pixels,
        font.atlas_pixmap.w,
        font.atlas_pixmap.h,
        0,
        1,
        nil
    )
    stbtt.PackSetOversampling(&pack_context, 4, 4)
    stbtt.PackFontRange(
        &pack_context,
        raw_data(font.font_data[:]),
        0,
        -cast(f32)font_size_px,
        32,
        96,
        raw_data(font.packedchar_array[:])
    )
    font.font_size_px = font_size_px
    stbtt.PackEnd(&pack_context)
    ok: bool
    font.atlas_tex_id, ok = renderer->create_texture_from_pixmap(font.atlas_pixmap)
    assert(ok)
    font.ok = true
    return font
}

get_text_width :: proc(font: ^Font, str: string) -> i32 {
// {{{
    width: f32
    max_height: f32
    pen_x: f32 = 0.0
    for r in str { 
        char_index := cast(i32)r - 32
        pen_x += font.packedchar_array[char_index].xadvance
    }
    return cast(i32)math.round(pen_x)
// }}}
}

get_text_height :: proc(font: ^Font) -> i32 {
    return font.font_size_px
}

@(private)
draw_text :: proc(
    renderer: ^Renderer,
    font: ^Font,
    offset: vec2f,
    text: string,
    color: Color4f) 
{
// {{{
    if !font.ok do return
    offset := offset
    pen := offset
    ascent, descent, line_gap: i32
    stbtt.GetFontVMetrics(&font.font_info, &ascent, &descent, &line_gap)
    scale := stbtt.ScaleForPixelHeight(&font.font_info, cast(f32)font.font_size_px)
    scaled_ascent := cast(f32)ascent * scale
    baseline_y := pen.y + (cast(f32)(ascent - descent + line_gap) * scale)

    for r in text {
        ch := cast(i32)r - 32
        log.assertf(ch >= 0 && ch <= 96, "Invalid character! ('{}')")
        // if ch < 0 || ch > 96 do continue
        quad: stbtt.aligned_quad
        x, y: f32
        stbtt.GetPackedQuad(
            raw_data(font.packedchar_array[:]),
            font.atlas_pixmap.w,
            font.atlas_pixmap.h,
            ch,
            &pen.x,
            &baseline_y,
            &quad,
            true
        )
        renderer->push_quad_textured(
            {
                quad.x0,
                quad.y0,
                quad.x1-quad.x0,
                quad.y1-quad.y0,
            },
            color,
            cast(Texture)font.atlas_tex_id,
            {
                {quad.s0, quad.t0},
                {quad.s1, quad.t1},
            }
        )
        // pen.x += ui.packedchar_array[ch].xadvance
    }
// }}} 
}

Command_ :: struct {
    command: Command,
    location: runtime.Source_Code_Location,
}

Draw_Context :: struct {
    command_buffer: sa.Small_Array(1024, Command_),
    clip_rect_stack: sa.Small_Array(16, Rect),
    renderer: ^Renderer,
    render_size: vec2,
    began: bool,
}

init :: proc(draw_context: ^Draw_Context) {
    draw_context^ = {}
}

// push_clip_rect :: proc(draw_context: ^Draw_Context, rect: Rect, loc := #caller_location) {
//     assert(draw_context.began, "Drawing hasn't begun!")
//     assert(sa.push_back(&draw_context.clip_rect_stack, rect), "Clip rect stack full", loc)
//     push_command(draw_context, Clip_Rect{rect=rect}, loc)
// }
//
// pop_clip_rect :: proc(draw_context: ^Draw_Context, loc := #caller_location) {
//     assert(draw_context.began, "Drawing hasn't begun!")
//     clip_rect, pop_ok := sa.pop_back_safe(&draw_context.clip_rect_stack)
//     assert(pop_ok, "Clip rect stack empty", loc)
//     push_command(draw_context, Clip_Rect{rect=clip_rect}, loc)
// }

// begin :: proc(draw_context: ^Draw_Context) {
//     assert(!draw_context.began, "Drawing already begun!")
//     draw_context.began = true
// 	sa.clear(&draw_context.command_buffer)
//     // draw_context.render_size = render_size
//     assert(sa.len(draw_context.clip_rect_stack) == 0, "Clip rect should be empty")
//     // draw_context.renderer->set_viewport(render_size)
// }

submit :: proc(draw_context: ^Draw_Context, renderer: ^Renderer, render_size: vec2) {
// {{{
    // assert(draw_context.began, "Drawing hasn't begun!")
    assert(sa.len(draw_context.clip_rect_stack) == 0, "Clip rect should be empty")
    draw_context.renderer = renderer
    draw_context.render_size = render_size
    draw_context.renderer->begin_frame(
        util.projection_mat_from_window_size(draw_context.render_size)
    )
    // log.debugf("Window size: %v", draw_context.render_size)
    defer draw_context.renderer->end_frame()
    for command in sa.slice(&draw_context.command_buffer) {
        #partial switch cmd in command.command {
        case Clear:
            draw_context.renderer->set_clear_color(cmd.color)
        case Fill_Rect:
            draw_context.renderer->push_quad_color(cmd.rect, cmd.color)
        case Stroke_Rect:
            offset_table := [Stroke_Alignment]f32{
                .Center=cmd.line_width/2,
                .Inward=-cmd.line_width,
                .Outward=cmd.line_width,
            }
            v := offset_table[cmd.alignment]
            // Top {{{
            draw_context.renderer->push_quad_color(
                Rectf {
                    cmd.rect.x-cmd.line_width,
                    cmd.rect.y-cmd.line_width,
                    cmd.rect.w+cmd.line_width,
                    cmd.line_width,
                },
                cmd.color,
            )
            // }}}
            // Bottom {{{
            draw_context.renderer->push_quad_color(
                Rectf {
                    cmd.rect.x-cmd.line_width,
                    cmd.rect.y+cmd.rect.h,
                    cmd.rect.w+cmd.line_width*2,
                    cmd.line_width,
                },
                cmd.color,
            )
            // }}}
            // Left {{{
            draw_context.renderer->push_quad_color(
                Rectf {
                    cmd.rect.x-cmd.line_width,
                    cmd.rect.y,
                    cmd.line_width,
                    cmd.rect.h,
                },
                cmd.color,
            )
            // }}}
            // Right {{{
            draw_context.renderer->push_quad_color(
                Rectf {
                    cmd.rect.x+cmd.rect.w,
                    cmd.rect.y-cmd.line_width,
                    cmd.line_width,
                    cmd.rect.h+cmd.line_width,
                },
                cmd.color,
            )
            // }}}
        case Stroke_Line:
            direction := linalg.normalize0(cmd.end - cmd.start)
            offset := vec2f{-direction.y, direction.x} * (cmd.line_width / 2)
            draw_context.renderer->push_tri(
                {
                    cmd.start + offset,
                    cmd.start - offset,
                    cmd.end - offset,
                },
                cmd.color
            )
            draw_context.renderer->push_tri(
                {
                    cmd.end - offset,
                    cmd.end + offset,
                    cmd.start + offset,
                },
                cmd.color
            )
        case Draw_Texture:
            draw_context.renderer->push_quad_textured(
                rect={
                    x=cmd.off.x,
                    y=cmd.off.y,
                    w=100, // FIXME:
                    h=100, // FIXME:
                },
                color=color_white,
                tex_id=cmd.texture,
            )
        case Draw_Text:
            draw_text(
                draw_context.renderer,
                cmd.font,
                vec2f{cmd.rect.x, cmd.rect.y}, //  TODO: cmd.pos,
                cmd.text,
                cmd.color
            )
        case Clip_Rect:
            draw_context.renderer->set_clip_rect(
                Rect {
                    cmd.rect.x,
                    draw_context.render_size.y - (cmd.rect.y - cmd.rect.h),
                    cmd.rect.w,
                    cmd.rect.h
                },
                command.location,
            )
        }
    }
    draw_context.began = false
	sa.clear(&draw_context.command_buffer)
// }}}
}

// measure_string :: proc(draw_context: ^Draw_Context, font: ^Font, text: string) -> vec2 {
// 	return {}
// }

push_command :: proc(draw_context: ^Draw_Context, command: Command, loc := #caller_location) {
    assert(sa.append(&draw_context.command_buffer, Command_{command=command, location=loc}), "Too many draw commands!\a", loc)
}

color_4b_to_f :: util.color4b_to_4f

color_f_to_4b :: util.color4f_to_4b

alpha_blend :: proc(top, bottom: Color_f) -> Color_f {
    one_minus_src_alpha := 1.0 - top.a
    final_c := top * top.a + bottom * one_minus_src_alpha
    final_c.a = 1.0
    return final_c
}

Pixmap :: util.Pixmap

import "core:slice"

_fill :: proc "contextless" (pixmap: Pixmap, color: Color_f) {
    area := pixmap.w * pixmap.h
    pixels := cast([^]Color_f)pixmap.pixels

    slice.fill((cast([^]Color_4b)pixmap.pixels)[:area], color_f_to_4b(color))
}

_fill_rect :: proc "contextless" (pixmap: Pixmap, r: Rect, color: Color_f) {
    if color.a <= 0 do return
    b := util.rect_to_bbox(r)
    x0, x1, y0, y1 := b.x0, b.x1, b.y0, b.y1 
    if pixmap.w == 0 || pixmap.h == 0 do return
    if x0 > x1 do x0, x1 = x1, x0
    if y0 > y1 do y0, y1 = y1, y0
    if x0 >= pixmap.w || y0 >= pixmap.h do return
    if x0 < 0 do x0 = 0
    if y0 < 0 do y0 = 0
    if x1 > pixmap.w do x1 = pixmap.w
    if y1 > pixmap.h do y1 = pixmap.h 

    pixels := cast([^]Color_4b)pixmap.pixels
    row := y0 * pixmap.pitch
    
    if color.a >= 1.0 {
        c_u8 := color_f_to_4b(color)
        for y in y0..<y1 {
            for x in x0..<x1 {
                pixels[row + x] = c_u8
            }
            row += pixmap.pitch
        }
    } else {
        one_minus_src_alpha := 1.0 - color.a
        src_b := color * color.a
        for y in y0..<y1 {
            for x in x0..<x1 {
                blended_c := src_b + color_4b_to_f(pixels[row+x]) * one_minus_src_alpha
                blended_c.a = 1.0
                pixels[row + x] = color_f_to_4b(blended_c)
            }
            row += pixmap.pitch
        }
    }
}
// load_pixmap :: proc(filename: cstring) -> (Pixmap, bool) {
//     w, h, channels: i32
//     pixels := stbi.load(filename, &w, &h, &channels, 4)
//     if pixels == nil {
//         return {}, false
//     }
//     area := int(w * h * 4)
//     for i := 0; i < area; i += 4 {
//         // Is this right?
//         pixels[i], pixels[i+2] = pixels[i+2], pixels[i]
//     }
//     return Pixmap { pixels=pixels, w=w, h=h, pitch=w*4 }, true
// }
//
// delete_pixmap :: proc(pixmap: ^Pixmap) {
//     mem.free(pixmap.pixels)
//     pixmap.pixels = nil
//     pixmap.w = 0
//     pixmap.h = 0
// }


// FIXME:
// stroke_rect :: proc(draw_context: ^Draw_Context, rect: Rect, color: Color_f, pixel_width: i32) {
//     if pixel_width == 0 do return
//     b := util.rect_to_bbox(rect)
//     x0, x1, y0, y1 := b.x0, b.x1, b.y0, b.y1 
//
//     // top
//     fill_rect(draw_context, util.bbox_to_rect({x0, y0 - pixel_width, x1, y0}), color)
//     // bottom
//     fill_rect(draw_context, util.bbox_to_rect({x0, y1, x1, y1 + pixel_width}), color)
//     // left
//     fill_rect(draw_context, util.bbox_to_rect(
//         {x0 - pixel_width, y0 - pixel_width, x0, y1 + pixel_width}
//     ), color)
//     // right
//     fill_rect(draw_context, util.bbox_to_rect(
//         {x1, y0 - pixel_width, x1 + pixel_width, y1 + pixel_width}
//     ), color)
// }
