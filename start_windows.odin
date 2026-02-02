#+build windows
package main

import "core:log"
import "core:time"
import "core:c"
import "base:intrinsics"
import win "core:sys/windows"
import "base:runtime"
import "odinlib:util"
import "draw"

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

// FIXME: Mouse position seems to be off after setting dpi awareness

wide_string_literal :: intrinsics.constant_utf16_cstring

Draw_Context_Backend_Type :: enum {Software, OpenGL, Direct2D}
draw_context_backend := Draw_Context_Backend_Type.OpenGL
draw_context: [Draw_Context_Backend_Type]draw.Draw_Context

main :: proc() {
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
        win.utf8_to_wstring(PRE_INIT_WINDOW_TITLE, context.temp_allocator), 
        win.WS_OVERLAPPEDWINDOW,
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        PRE_INIT_WINDOW_SIZE.x,
        PRE_INIT_WINDOW_SIZE.y,
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
    when false && ODIN_DEBUG {
        // FIXME: Causes weird memory bug. Look at Handmade Hero code
        CreateContextAttribsARB: win.CreateContextAttribsARBType
        win.gl_set_proc_address(&CreateContextAttribsARB, "wglCreateContextAttribsARB")
        assert(CreateContextAttribsARB != nil, "no wglCreateContextAttribsARB")
        attrib_list := []i32 {
            win.WGL_CONTEXT_MAJOR_VERSION_ARB, GL_VERSION[0],
            win.WGL_CONTEXT_MINOR_VERSION_ARB, GL_VERSION[1],
            win.WGL_CONTEXT_FLAGS_ARB, (
                win.WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB | win.WGL_CONTEXT_DEBUG_BIT_ARB
            ),
            win.WGL_CONTEXT_PROFILE_MASK_ARB, win.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
            0
        }
        // win.wglDeleteContext(gl_context)
        gl_context = CreateContextAttribsARB(
            device_context,
            nil,
            raw_data(attrib_list)
        )
        assert(gl_context != nil)
        win.wglMakeCurrent(device_context, gl_context)
    }
    win.ReleaseDC(window_handle, device_context)
    // }}}

    win.ShowWindow(window_handle, win.SW_SHOW)
    win.UpdateWindow(window_handle)
    // }}}

    draw_context[.Software] = draw.new_draw_context_sw(
        draw.Draw_Context_VTable{
            get_render_target_dpi = proc(draw_context: ^draw.Draw_Context) -> i32 {
                return cast(i32)win.GetDpiForWindow(window_handle)
            },

            end_frame = proc(draw_context: ^draw.Draw_Context) {
                device_context := win.GetDC(window_handle)
                rect: win.RECT
                win.GetClientRect(window_handle, &rect)
                win.BitBlt(
                    device_context, 
                    0,
                    0,
                    rect.right-rect.left,
                    rect.bottom-rect.top, 
                    memory_device_context, 
                    0,
                    0,
                    win.SRCCOPY
                )
                win.ReleaseDC(window_handle, device_context)
                // TODO: sleep for remainder of frame
                time.sleep(16666 * time.Microsecond)
            },
            resize = proc(_: ^draw.Draw_Context, _: util.vec2) {
                setup_framebuffer()
            },
        }
    )
    setup_framebuffer()
    #partial switch draw_context_backend {
    case .Direct2D:
        draw_context[draw_context_backend] = draw.new_draw_context_direct2d(window_handle)
    case .OpenGL:
        draw_context[draw_context_backend] = draw.new_draw_context_opengl()
    }
    assert(draw_context[draw_context_backend].data != nil)
    app_init(App_Init{
        draw_context = &draw_context[draw_context_backend],
        handle_platform_command = handle_platform_command,
    })

    running = true
    SwapIntervalEXT: win.SwapIntervalEXTType
    win.gl_set_proc_address(&SwapIntervalEXT, "wglSwapIntervalEXT")
    assert(SwapIntervalEXT != nil, "no wglSwapIntervalEXT")
    SwapIntervalEXT(1)
    loop: for {
        message: win.MSG

        for win.PeekMessageW(&message, nil, 0, 0, win.PM_REMOVE) {
            win.TranslateMessage(&message)
            win.DispatchMessageW(&message)
            if message.message == win.WM_QUIT {
                break loop
            }
        }
        app_context.draw_context = &draw_context[draw_context_backend]
        app_update()
    }
}

setup_framebuffer :: proc() { // {{{
    sw_context := cast(^draw.SW_Context)(draw_context[.Software].data)
    if sw_context == nil do return
    if bitmap_handle != nil {
        win.DeleteObject(cast(win.HGDIOBJ)bitmap_handle)
        bitmap_handle = nil
    }
    rect: win.RECT
    win.GetClientRect(window_handle, &rect)
    width := cast(i32)(rect.right - rect.left)
    height := cast(i32)(rect.bottom - rect.top)
    sw_context.pixmap.w = width
    sw_context.pixmap.h = height
    bitmap_info = win.BITMAPINFO {
        bmiHeader={
            biSize=cast(u32)size_of(win.BITMAPINFOHEADER),
            biWidth=width,
            biHeight=-height,
            biPlanes=1,
            biBitCount=32,
            biCompression=win.BI_RGB,
        },
    }
    device_context := win.GetDC(window_handle)
    if memory_device_context == nil {
        memory_device_context = win.CreateCompatibleDC(device_context)
    }
    bitmap_handle = win.CreateDIBSection(
        nil,
        &bitmap_info,
        0,
        cast(^^rawptr)&sw_context.pixmap.pixels,
        nil,
        0
    )
    assert(bitmap_handle != nil)
    assert(sw_context.pixmap.pixels != nil)
    win.SelectObject(memory_device_context, cast(win.HGDIOBJ)bitmap_handle)
    win.ReleaseDC(window_handle, device_context)
}
///}}}

win32_cursor: cstring
// window proc {{{
window_proc :: proc "stdcall" (
    window_handle: 
    win.HWND, 
    message: c.uint, 
    wparam: win.WPARAM, 
    lparam: win.LPARAM) -> win.LRESULT 
{
    context = global_context
    exit_code: win.LRESULT
    window_event: Maybe(util.Window_Event)
    switch message {
    case win.WM_CREATE:
    case win.WM_COMMAND:
        switch win.LOWORD(wparam) {
        case MENU_ID_QUIT:
            win.PostQuitMessage(0)
        case MENU_ID_DIRECT2D:
            draw_context_backend = .Direct2D
        case MENU_ID_SW:
            draw_context_backend = .Software
            setup_framebuffer()
        }
    case win.WM_PAINT:
        paintstruct: win.PAINTSTRUCT
        device_context := win.BeginPaint(window_handle, &paintstruct)
        win.EndPaint(window_handle, &paintstruct)
        if running {
            app_render()
        }
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
                repeated=(lparam & (1 << 30)) != 0,
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
            app_handle_event(event)
        }
    }
    return exit_code
}
// }}}

handle_platform_command :: proc(command: util.Platform_Command) {
    #partial switch command.type {
    case .Quit:
        win.DestroyWindow(window_handle)
    case .Rename_Window:
        title_ws := win.utf8_to_wstring(command.title, context.temp_allocator)
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
}
