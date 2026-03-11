package draw

import "odinlib:util"
import "core:math"
import "core:log"

vec2f :: util.vec2f
BBoxf :: util.BBoxf
Rectf :: util.Rectf
// vec2f :: util.vec2
// Color_f :: util.Color_f

Clear :: struct { color: Color_f }

Fill_Rect :: struct {
    rect: Rectf,
    color: Color_f,
}

Fill_Rounded_Rect :: struct {
    rect: Rectf,
    color: Color_f,
    corner_radius: f32,
}

Stroke_Rect :: struct {
    rect: Rectf,
    color: Color_f,
    line_width: f32,
    style: Stroke_Style,
}

Fill_Circle :: struct {
    origin: vec2f,
    radius: f32,
    color: Color_f,
}

Stroke_Line :: struct { // TODO: [2]Vertex
    pts: [2]vec2f,
    start, end: vec2f,
    line_width: f32,
    color: Color_f,
    style: Stroke_Style,
}

Fill_Tri :: struct {
    v0, v1, v2: [3]vec2f,
    color: Color4f,
}

Fill_Quad :: [4]Vertex

// struct {
//     v0, v1, v2: vec2f,
//     color: Color_f,
// }

Draw_Texture :: struct {
    texture: Texture,
    off: vec2f,
}

Draw_Text :: struct {
    text: string,
    font: ^Font,
    rect: Rectf, // pos: vec2f,
    color: Color_f,
}

Clip_Rect :: struct {
    rect: Rect,
}

Command :: union {
    Clear,
    Fill_Rect,
    Fill_Rounded_Rect, 
    Stroke_Rect,
    Fill_Circle,
    Stroke_Line,
    Fill_Tri,
    Draw_Texture,
    Draw_Text,
    Fill_Quad,
    Clip_Rect,
}

Stroke_Style :: enum {
    Solid,
    Dash,
}

map_coord :: proc(v: f32, size, offset: f32) -> f32 {
    return ((v * 0.5 + 0.5) * size) + offset
}

map_point :: proc(v: vec2f, rect: Rectf) -> vec2f {
    sv := (v * 0.5 + 0.5) * vec2f{cast(f32)rect.w, cast(f32)rect.h}
    return {sv.x, sv.y} + {rect.x, rect.y}
}

fill_rect_nc :: proc(draw_context: ^Draw_Context, rc: BBoxf, color: Color_f, bbox: Rectf) {
    push_command(draw_context, Fill_Rect {
        rect = util.bbox_to_rect(util.BBoxf {
            x0=map_coord(rc.x0, bbox.w, bbox.x),
            y0=map_coord(rc.y0, bbox.h, bbox.y),
            x1=map_coord(rc.x1, bbox.w, bbox.x),
            y1=map_coord(rc.y1, bbox.h, bbox.y),
        }),
        color=color,
    })
}

stroke_rect_nc :: proc(
    draw_context: ^Draw_Context,
    rc: BBoxf,
    color: Color_f, 
    line_width: f32,
    bbox: Rectf) 
{
    push_command(draw_context, Stroke_Rect {
        rect = util.bbox_to_rect(util.BBoxf {
            x0=map_coord(rc.x0, bbox.w, bbox.x),
            y0=map_coord(rc.y0, bbox.h, bbox.y),
            x1=map_coord(rc.x1, bbox.w, bbox.x),
            y1=map_coord(rc.y1, bbox.h, bbox.y),
        }),
        line_width=line_width,
        color=color,
    })
}

stroke_line_nc :: proc(draw_context: ^Draw_Context, p0, p1: vec2f, color: Color_f, bbox: Rectf) {
    push_command(draw_context, Stroke_Line {
        pts={
            map_point(p0, bbox),
            map_point(p1, bbox),
        },
        color=color,
    })
}

fill_tri_nc :: proc(draw_context: ^Draw_Context, v0, v1, v2: vec2f, color: Color_f, bbox: Rectf) {
    push_command(draw_context, Fill_Tri {
        v0 = map_point(v0, bbox),
        v1 = map_point(v1, bbox),
        v2 = map_point(v2, bbox),
        color=color,
    })
}

fill_circle_nc :: proc(
    draw_context: ^Draw_Context, 
    origin: vec2f, 
    radius: f32, 
    color: Color_f, 
    bbox: Rectf)
{
    push_command(draw_context, Fill_Circle {
        origin = map_point(origin, bbox),
        radius = (radius * cast(f32)math.min(bbox.w, bbox.h)) / 2,
        color=color,
    })
}
