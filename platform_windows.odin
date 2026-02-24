#+build windows
package main

import "core:log"
import "core:time"
import "core:c"
import "base:intrinsics"
import win "core:sys/windows"
import "base:runtime"
import "odinlib:util"
import gl "vendor:OpenGL"
import sa "core:container/small_array"
import "src"
import "core:slice"
import "src/draw"
import "core:fmt"

when src.PLATFORM_BACKEND == "native" {
MENU_ID_QUIT     :: 100
MENU_ID_DIRECT2D :: 101
MENU_ID_SW       :: 102

previous_frame_time: time.Tick 
window_handle: win.HWND
running: bool
global_context: runtime.Context
bitmap_handle: win.HBITMAP
bitmap_info: win.BITMAPINFO
memory_device_context: win.HDC
min_window_size, max_window_size: Maybe(util.vec2)
SwapIntervalEXT: win.SwapIntervalEXTType
framebuffer_pixmap: util.Pixmap
renderer_backend := util.Renderer_Backend.Opengl

// FIXME: Mouse position seems to be off after setting dpi awareness

wide_string_literal :: intrinsics.constant_utf16_cstring
previous_frame_tick: time.Tick
window_events: sa.Small_Array(64, util.Window_Event)


main :: proc() {
    t: time.Tick
    context.logger = log.create_console_logger()
    context.logger.options -= {.Date}
    global_context = context

    // win32 setup {{{
    app_name := cast(cstring16)wide_string_literal("WINAPP")
    program_instance := cast(win.HANDLE)win.GetModuleHandleA(nil);
    window_class: win.WNDCLASSW
    window_class.style = win.CS_HREDRAW | win.CS_VREDRAW
    window_class.lpfnWndProc = window_proc
    window_class.cbClsExtra = 0
    window_class.cbWndExtra = 0
    window_class.hInstance = program_instance
    window_class.hIcon = cast(win.HICON)win.LoadImageW(
        nil, 
        wide_string_literal("resources/sim6502.ico"),
        win.IMAGE_ICON, 
        0,
        0,
        win.LR_DEFAULTSIZE | win.LR_LOADFROMFILE
    )
    window_class.hCursor = nil 
    window_class.hbrBackground = cast(win.HBRUSH)win.GetStockObject(win.WHITE_BRUSH)
    window_class.lpszMenuName = wide_string_literal("TryMenu")
    window_class.lpszClassName = app_name

    assert(win.RegisterClassW(&window_class) != 0)

    window_handle = win.CreateWindowW(
        app_name,
        wide_string_literal("WIN32 APP"), 
        win.WS_OVERLAPPEDWINDOW,
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        nil,
        nil,
        program_instance,
        nil
    )
    assert(window_handle != nil)
    // opengl setup {{{
    suggested_pixel_format_desc: win.PIXELFORMATDESCRIPTOR
    pixel_format_desc := win.PIXELFORMATDESCRIPTOR {
        nSize=size_of(win.PIXELFORMATDESCRIPTOR),
        nVersion=1,
        dwFlags=win.PFD_DRAW_TO_WINDOW | win.PFD_DOUBLEBUFFER | win.PFD_SUPPORT_OPENGL,
        iPixelType=win.PFD_TYPE_RGBA,
        iLayerType=win.PFD_MAIN_PLANE,
        cColorBits=32,
        cDepthBits=24,
        cAlphaBits=8,
        cStencilBits=8,
    }
    device_context := win.GetDC(window_handle)
    pfd_index := win.ChoosePixelFormat(
        device_context,
        &pixel_format_desc,
    )
    win.DescribePixelFormat(
        device_context,
        pfd_index,
        size_of(win.PIXELFORMATDESCRIPTOR),
        &suggested_pixel_format_desc
    )
    win.SetPixelFormat(device_context, pfd_index, &suggested_pixel_format_desc)
    gl_context := win.wglCreateContext(device_context)
    win.wglMakeCurrent(device_context, gl_context)
    when true && ODIN_DEBUG {
        CreateContextAttribsARB: win.CreateContextAttribsARBType
        win.gl_set_proc_address(&CreateContextAttribsARB, "wglCreateContextAttribsARB")
        assert(CreateContextAttribsARB != nil, "no wglCreateContextAttribsARB")
        attrib_list := []i32 {
            win.WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
            win.WGL_CONTEXT_MINOR_VERSION_ARB, 3,
            win.WGL_CONTEXT_FLAGS_ARB, (
                win.WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB | win.WGL_CONTEXT_DEBUG_BIT_ARB
            ),
            win.WGL_CONTEXT_PROFILE_MASK_ARB, win.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0
        }
        old_gl_context := gl_context
        gl_context = CreateContextAttribsARB(
            device_context,
            nil,
            raw_data(attrib_list)
        )
        assert(gl_context != nil)
        win.wglDeleteContext(old_gl_context)
        win.wglMakeCurrent(device_context, gl_context)
    }
    win.ReleaseDC(window_handle, device_context)
    gl.load_up_to(3, 3, win.gl_set_proc_address)
    // }}}

    win.ShowWindow(window_handle, win.SW_SHOW)
    win.UpdateWindow(window_handle)
    // }}}
    
    client_rect: win.RECT
    win.GetClientRect(
        window_handle,
        &client_rect
    )
    update_framebuffer_win32()
    src.init(src.App_Init{
        window_size=util.vec2{
            client_rect.right-client_rect.left,
            client_rect.bottom-client_rect.top,
        },
        handle_platform_command = handle_platform_command,
        dots_per_inch=cast(i32)win.GetDpiForWindow(window_handle),
    })

    running = true
    win.gl_set_proc_address(&SwapIntervalEXT, "wglSwapIntervalEXT")
    assert(SwapIntervalEXT != nil, "no wglSwapIntervalEXT")
    SwapIntervalEXT(0)
    ogl_renderer: draw.Renderer_OGL
    assert(draw.ogl_renderer_init(&ogl_renderer))
    sw_renderer: draw.Renderer_SW
    assert(draw.sw_renderer_init(&sw_renderer, framebuffer_pixmap))
    sw_renderer.resize = proc(_: ^draw.Renderer, _, _: i32) {
        update_framebuffer_win32() 
    }
    loop: for {
        message: win.MSG
        sa.clear(&window_events)

        for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
            win.TranslateMessage(&message)
            win.DispatchMessageW(&message)
            if message.message == win.WM_QUIT {
                break loop
            }
        }
        if !src.update({renderers=[]^draw.Renderer{&ogl_renderer, &sw_renderer}}) {
            break 
        }

        device_context := win.GetDC(window_handle)
        if renderer_backend == .Opengl {
            win.SwapBuffers(device_context)
        } else {   
            win.BitBlt(
                device_context,
                0,
                0,
                framebuffer_pixmap.w,
                framebuffer_pixmap.h,
                memory_device_context, 
                0,
                0,
                win.SRCCOPY
            )
        }
        win.ReleaseDC(window_handle, device_context)
        if true {
            util.wait_frame_interval(&previous_frame_tick, 16 * time.Millisecond)
        }
    }
}

win32_cursor: cstring
mouse_position: util.vec2

test_update :: proc(_: src.App_Update) -> bool {
    area := framebuffer_pixmap.w * framebuffer_pixmap.h
    pixels := cast([^]util.Color4b)framebuffer_pixmap.pixels
    x := cast(f32)mouse_position.x / cast(f32)framebuffer_pixmap.w
    y := cast(f32)mouse_position.y / cast(f32)framebuffer_pixmap.h
    slice.fill((cast([^]util.Color4b)pixels)[:area], util.color4f_to_4b({x, 0, y, 0}))
    draw._fill_rect(framebuffer_pixmap, {mouse_position.x, mouse_position.y, 100, 100}, draw.color_magenta)
    device_context := win.GetDC(window_handle)
    win.BitBlt(device_context, 0, 0, framebuffer_pixmap.w, framebuffer_pixmap.h,
    memory_device_context, 0, 0, win.SRCCOPY)
    win.ReleaseDC(window_handle, device_context)
    return true
}

window_proc :: proc "stdcall" (
    window_handle: 
    win.HWND, 
    message: c.uint, 
    wparam: win.WPARAM, 
    lparam: win.LPARAM) -> win.LRESULT 
{
// {{{
    context = global_context
    exit_code: win.LRESULT
    window_event: Maybe(util.Window_Event)
    switch message {
    case win.WM_CREATE:
    case win.WM_COMMAND:
    case win.WM_PAINT:
        paintstruct: win.PAINTSTRUCT
        device_context := win.BeginPaint(window_handle, &paintstruct)
        if running {
            if renderer_backend == .Opengl {
                // win.SwapBuffers(device_context)
            } else if renderer_backend == .Software {
                src.render()
                win.BitBlt(
                    device_context,
                    0,
                    0,
                    framebuffer_pixmap.w,
                    framebuffer_pixmap.h,
                    memory_device_context, 
                    0,
                    0,
                    win.SRCCOPY
                )
                // SwapIntervalEXT(0)
                // d := win.GetDC(window_handle)
                // win.SwapBuffers(d)
                // win.ReleaseDC(window_handle, d)
                // SwapIntervalEXT(1)
            }
        }
        win.EndPaint(window_handle, &paintstruct)
    case win.WM_CHAR:
        window_event = util.Window_Event {
            type=.Char_Input,
            char_codepoint=cast(rune)wparam,
        }
    case win.WM_KEYUP, win.WM_KEYDOWN:
        window_event = util.Window_Event {
            type=.Key,
            key={
                keycode=util.translate_vk(wparam),
                pressed=message == win.WM_KEYDOWN,
                repeated=(message == win.WM_KEYDOWN) && ((lparam & (1 << 30)) != 0),
            },
        }
    case win.WM_LBUTTONDOWN:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Left,
                pressed=true,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_LBUTTONUP:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Left,
                pressed=false,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_MBUTTONDOWN:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Middle,
                pressed=true,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_MBUTTONUP:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Middle,
                pressed=false,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_RBUTTONDOWN:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Right,
                pressed=true,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_RBUTTONUP:
        window_event = util.Window_Event {
            type=.Mouse_Button,
            mouse_button={
                button=.Right,
                pressed=false,
                position={
                    win.GET_X_LPARAM(lparam), 
                    win.GET_Y_LPARAM(lparam) 
                },
            }
        }
    case win.WM_MOUSEMOVE:
        mouse_position={
                win.GET_X_LPARAM(lparam), 
                win.GET_Y_LPARAM(lparam) 
            }
        window_event = util.Window_Event {
            type=.Mouse_Move,
            vec2={
                win.GET_X_LPARAM(lparam), 
                win.GET_Y_LPARAM(lparam) 
            },
        }
    case win.WM_MOUSEWHEEL:
        window_event = util.Window_Event {
            type=.Mouse_Wheel,
            vec2={
                0,
                cast(i32)(win.GET_WHEEL_DELTA_WPARAM(wparam) / win.WHEEL_DELTA),
            }
        }
    case win.WM_MOUSEHWHEEL:
        window_event = util.Window_Event {
            type=.Mouse_Wheel,
            vec2={
                cast(i32)(win.GET_WHEEL_DELTA_WPARAM(wparam) / win.WHEEL_DELTA),
                0,
            }
        }
    case win.WM_SIZE:
        width := win.GET_X_LPARAM(lparam)
        height := win.GET_Y_LPARAM(lparam)
        window_event = util.Window_Event {
            type=.Window_Resize,
            vec2={width, height},
        }
        update_framebuffer_win32()
    case win.WM_GETMINMAXINFO:
        min_max_info := transmute(^win.MINMAXINFO)lparam
        if min_size, ok := min_window_size.?; ok {
            min_max_info.ptMinTrackSize = win.POINT{min_size.x, min_size.y}
        }
        if max_size, ok := max_window_size.?; ok {
            min_max_info.ptMaxTrackSize = win.POINT{max_size.x, max_size.y}
        }
    case win.WM_SETCURSOR:
        if win32_cursor != nil && win.LOWORD(lparam) == win.HTCLIENT {
            win.SetCursor(win.LoadCursorA(nil, win32_cursor))
        } else {
            win.DefWindowProcW(window_handle, message, wparam, lparam)
        }
    case win.WM_CLOSE:
        window_event = util.Window_Event {
            type=.Window_Close,
        }
    case win.WM_DESTROY:
        win.PostQuitMessage(0)
    case:
        exit_code = win.DefWindowProcW(window_handle, message, wparam, lparam)
    }
    if running {
        if event, ok := window_event.?; ok {
            src.handle_event(event)
        }
    }
    return exit_code
// }}}
}

handle_platform_command :: proc(command: util.Platform_Command) {
// {{{
    #partial switch command.type {
    case .Quit:
        win.DestroyWindow(window_handle)
    case .Rename_Window:
        title := command.title
        when ODIN_DEBUG {
            title = fmt.tprintf("%s [WIN32]", command.title)
        } 
        title_ws := win.utf8_to_wstring(title, context.temp_allocator)
        win.SetWindowTextW(window_handle, title_ws)
    case .Change_Mouse_Cursor:
        switch command.cursor_type {
        case .Normal:
            win32_cursor = win.IDC_ARROW
        case .Wait:
            win32_cursor = win.IDC_WAIT
        case .IBeam:
            win32_cursor = win.IDC_IBEAM
        case .Hand:
            win32_cursor = win.IDC_HAND
        }
        win.SetCursor(win.LoadCursorA(nil, win32_cursor))
        log.debugf("Cursor set to %v", command.cursor_type)
    case .Resize_Window:
        if size, ok := command.size.?; ok {
        win.SetWindowPos(
            window_handle, 
            nil, 
            0, 
            0,
            size.x, 
            size.y, 
            win.SWP_NOMOVE | win.SWP_NOOWNERZORDER
        )
    }
    case .Set_Window_Min_Size:
        min_window_size = command.size
    case .Set_Window_Max_Size:
        max_window_size = command.size
    case .Change_Window_Icon:
        path_ws := win.utf8_to_wstring(command.path, context.temp_allocator)
        win.SetClassLongPtrW(
            window_handle,
            win.GCLP_HICON,
            transmute(int)win.LoadImageW(
                nil, 
                path_ws,
                win.IMAGE_ICON, 
                0,
                0,
                win.LR_DEFAULTSIZE | win.LR_LOADFROMFILE
            )
        )
    }
// }}}
}

update_framebuffer_win32 :: proc() {
// {{{
    rect: win.RECT
    win.GetClientRect(window_handle, &rect)
    w, h := rect.right - rect.left, rect.bottom - rect.top
    framebuffer_pixmap.w = w
    framebuffer_pixmap.h = h
    framebuffer_pixmap.pitch = w
    bitmap_info = win.BITMAPINFO {
        bmiHeader={
            biSize=u32(size_of(win.BITMAPINFOHEADER)),
            biWidth=w,
            biHeight=-h,
            biPlanes=1,
            biBitCount=32,
            biCompression=win.BI_RGB,
        },
    }
    device_context := win.GetDC(window_handle)
    if memory_device_context != nil {
        win.DeleteDC(memory_device_context)
    }
    memory_device_context = win.CreateCompatibleDC(device_context)
    bitmap_handle = win.CreateDIBSection(
        nil,
        &bitmap_info, 
        0,
        cast(^^rawptr)&framebuffer_pixmap.pixels,
        nil,
        0
    )
    assert(bitmap_handle != nil)
    assert(framebuffer_pixmap.pixels != nil)
    win.SelectObject(memory_device_context, cast(win.HGDIOBJ)bitmap_handle)
    win.ReleaseDC(window_handle, device_context)
    stride := ((((bitmap_info.bmiHeader.biWidth * cast(i32)bitmap_info.bmiHeader.biBitCount) + 31) & ~cast(i32)31) >> 3)
// }}}
}
}
