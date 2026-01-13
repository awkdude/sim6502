package util

import "core:unicode"
import "core:math"
import "base:runtime"
import "base:intrinsics"

PLATFORM_BACKEND :: #config(BACKEND, "native")

normalize_to_range :: proc(value, mini, maxi, minf, maxf: f32) -> f32 {
    return ((value - mini) / (maxi - mini)) * (maxf - minf) + minf;
}

point_in_rect :: proc(p: vec2, rect: Rect) -> bool {
    return p.x >= rect.x && p.x < (rect.x + rect.w) && 
        p.y >= rect.y && p.y < (rect.y + rect.h)
}

dip_to_px :: proc(dip, dots_per_inch: i32) -> i32 {
    return i32(cast(f32)dip / 96.0 * cast(f32)dots_per_inch)
}

size_to_rect :: proc(size: vec2) -> Rect {
    return Rect { w=size.x, h=size.y }
}

scale_vec2_s :: proc(v: vec2, s: f32) -> vec2 {
    return vec2 {
        cast(i32)(cast(f32)v.x * s),
        cast(i32)(cast(f32)v.y * s),
    }
}

scale_vec2_v :: proc(v: vec2, sv: vec2f) -> vec2 {
    return vec2 {
        cast(i32)(cast(f32)v.x * sv.x),
        cast(i32)(cast(f32)v.y * sv.y),
    }
}

scale_vec2 :: proc {
    scale_vec2_s,
    scale_vec2_v,
}

pos_size_to_rect :: proc(pos, size: vec2) -> Rect {
    return Rect {x=pos.x, y=pos.y, w=size.x, h=size.y}
}

bbox_to_rect :: proc(bbox: BBox) -> Rect {
    return Rect {
        x=min(bbox.x0, bbox.x1),
        y=min(bbox.y0, bbox.y1),
        w=math.abs(bbox.x1 - bbox.x0),
        h=math.abs(bbox.y1 - bbox.y0),
    }
}

rect_to_bbox :: proc(rect: Rect) -> BBox {
    bbox := BBox {
        x0=rect.x,
        y0=rect.y,
        x1=rect.x+rect.w,
        y1=rect.y+rect.h,
    }
    if rect.w < 0 {
        bbox.x0, bbox.x1 = bbox.x1, bbox.x0
    }
    if rect.h < 0 {
        bbox.y0, bbox.y1 = bbox.y1, bbox.y0
    }
    return bbox
}

rect_centered_in_rect :: proc(inner_rect, outer_rect: Rect) -> Rect {
    outer_center := vec2{outer_rect.w / 2, outer_rect.h/2}
    return Rect {
        outer_center.x - (inner_rect.w / 2),
        outer_center.y - (inner_rect.h / 2),
        inner_rect.w,
        inner_rect.h,
    }
}

union_rect :: proc(r0, r1: Rect) -> Rect {
    // TODO: This seems kinda redundant. Optimize!
    bbox0 := rect_to_bbox(r0)
    bbox1 := rect_to_bbox(r1)
    return bbox_to_rect(BBox {
        x0=min(bbox0.x0, bbox1.x0),
        y0=min(bbox0.y0, bbox1.y0),
        x1=max(bbox0.x1, bbox1.x1),
        y1=max(bbox0.y1, bbox1.y1),
    })
}

vec2 :: [2]i32

Color_f :: [4]f32

// NOTE: The ordering is dependent on target platform
// when ODIN_OS == .Windows {
Color_4b :: struct {
    b, g, r, a: u8,
}
// }

Pixmap :: struct {
    pixels: rawptr,
    w, h: i32,
}

Rect :: struct {
    x, y, w, h: i32,
}

BBox :: struct {
    x0, y0, x1, y1 : i32,
}

vec2f :: [2]f32
BBoxf :: struct {
    x0, y0, x1, y1 : f32,
}

Window_Event :: struct {
    using data: struct #raw_union {
        key: struct {
            keycode: u32,
            pressed, repeated: bool,
        },
        char_codepoint: rune,
        mouse_button: struct {
            button: Mouse_Button,
            pressed: bool,
            position: vec2,
        },
        vec2: vec2,
    },
    type: Window_Event_Type,
}


Window_Event_Type :: enum {
    Key,
    Char_Input,
    Window_Resize,
    Mouse_Button,
    Mouse_Move,
    Mouse_Wheel,
    Need_Repaint,
    Window_Close,
}

Mouse_Button :: enum {
    Left,
    Middle,
    Right,
}

Mouse_Cursor_Type :: enum {
    Normal,
    Wait,
    IBeam,
    Hand,
}

Platform_Command :: struct {
    using data: struct #raw_union {
        size: Maybe(vec2),
        cursor_type: Mouse_Cursor_Type,
        title, path: string,
    },
    type: enum {
        Rename_Window,
        Change_Mouse_Cursor,
        Resize_Window,
        Set_Window_Min_Size,
        Set_Window_Max_Size,
        Change_Window_Icon,
        Quit,
    },
}

Radix :: enum int {
    Binary = 2,
    Octal = 8,
    Decimal = 10,
    Hex = 16,
}

is_digit_in_radix :: proc(c: rune, radix: Radix) -> bool {
    result: bool
    switch radix {
    case .Binary:
        result = c == '0' || c == '1'
    case .Octal:
        result = c >= '0' && c <= '7'
    case .Decimal:
        result = c >= '0' && c <= '9'
    case .Hex:
        result = unicode.is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    }
    return result
}

wrap :: proc(x, y: $T) -> T
where intrinsics.type_is_integer(T), !intrinsics.type_is_array(T) 
{
    res := x % y
    return res + y if res < 0 else res
}

