package draw

import "core:mem"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:math/bits"
import "core:os"
import "core:log"
import stbtt "vendor:stb/truetype"
import stbi "vendor:stb/image"
import "odinlib:util"
import sa "core:container/small_array"

vec2   :: util.vec2
Rect   :: util.Rect
BBox :: util.BBox
Color_f  :: util.Color_f
Color_4b :: util.Color_4b


Vertex :: struct { 
    pos: vec2,
    color: Color_f,
}

Vertex_uv :: struct { 
    pos: vec2,
    uv: vec2f,
}

Font :: struct {
    font_data: []u8,
    packedchar_array: [96]stbtt.packedchar,
    font_info: stbtt.fontinfo,
    atlas_pixmap: util.Pixmap,
    atlas_tex_id: u32,
    font_path: string,
    font_size_px: i32,
}

Font_Resource_Type :: enum {
    System,
    File,
}

create_font :: proc(font_path: string, font_size_px: i32) -> Font {
    font: Font
    success: bool
    font.font_data, success = os.read_entire_file_from_filename(font_path)
    assert(success, "Font load error")
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
    stbtt.PackEnd(&pack_context)
    font.atlas_tex_id = util.create_texture_from_pixmap(font.atlas_pixmap)
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

Draw_Context :: struct {
    command_buffer: sa.Small_Array(1024, Command),
    clip_rect_stack: sa.Small_Array(8, Rect),
    renderer: Renderer,
    render_size: vec2,
}

context_init :: proc(draw_context: ^Draw_Context) {
    draw_context^ = {}
    assert(renderer_init(&draw_context.renderer))
}

push_clip_rect :: proc(using draw_context: ^Draw_Context, rect: Rect, loc := #caller_location) {
    assert(sa.push_back(&clip_rect_stack, rect), "Clip rect stack full", loc)
}

pop_clip_rect :: proc(using draw_context: ^Draw_Context, loc := #caller_location) {
    _, pop_ok := sa.pop_back_safe(&clip_rect_stack)
    assert(pop_ok, "Clip rect stack empty", loc)
}

begin_frame :: proc(draw_context: ^Draw_Context, render_size: vec2) {
	sa.clear(&draw_context.command_buffer)
    draw_context.render_size = render_size
}

end_frame :: proc(using draw_context: ^Draw_Context) {
    renderer_begin_frame(
        &renderer,
        util.projection_mat_from_window_size(render_size)
    )
    defer renderer_end_frame(&renderer)
    for command in sa.slice(&command_buffer) {
    #partial switch cmd in command {
    case Clear:
        renderer_clear_color(&renderer, cmd.color)
    case Fill_Rect:
        renderer_push_quad(&renderer, cmd.rect, cmd.color)
    case Stroke_Rect:
        renderer_push_outline_rect(&renderer, cmd.rect, cmd.color, cast(f32)cmd.line_width)
    }
    }
}

// measure_string :: proc(draw_context: ^Draw_Context, font: ^Font, text: string) -> vec2 {
// 	return {}
// }

push_command :: proc(using draw_context: ^Draw_Context, command: Command, loc := #caller_location) {
    assert(sa.append(&command_buffer, command), "Too many draw commands!", loc)
}

color_4b_to_f :: proc(color: Color_4b) -> Color_f {
    return Color_f {
        cast(f32)color.r / 255.0,
        cast(f32)color.g / 255.0,
        cast(f32)color.b / 255.0,
        cast(f32)color.a / 255.0,
    }
}

color_f_to_4b :: proc(color: Color_f) -> Color_4b {
    return Color_4b {
        r=cast(u8)math.round(color.r * 255.0),
        g=cast(u8)math.round(color.g * 255.0),
        b=cast(u8)math.round(color.b * 255.0),
        a=cast(u8)math.round(color.a * 255.0),
    }
}

alpha_blend :: proc(top, bottom: Color_f) -> Color_f {
    one_minus_src_alpha := 1.0 - top.a
    final_c := top * top.a + bottom * one_minus_src_alpha
    final_c.a = 1.0
    return final_c
}

Pixmap :: util.Pixmap

import "core:slice"

_fill :: proc(pixmap: ^Pixmap, color: Color_f) {
    area := pixmap.w * pixmap.h
    pixels := cast([^]Color_f)pixmap.pixels

    slice.fill((cast([^]Color_4b)pixmap.pixels)[:area], color_f_to_4b(color))
}

_fill_rect :: proc(pixmap: ^Pixmap, r: Rect, color: Color_f) {
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
    row := y0 * pixmap.w
    
    if color.a >= 1.0 {
        c_u8 := color_f_to_4b(color)
        for y in y0..<y1 {
            for x in x0..<x1 {
                pixels[row + x] = c_u8
            }
            row += pixmap.w
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
            row += pixmap.w
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
