#+ignore
package main
import win "core:sys/windows"
import "core:strings"
import "core:math/bits"
import "core:log"
import "base:runtime"

dip_to_ddp :: proc(dip, dots_per_inch: i32) -> i32 {
    return i32((cast(f32)dip / 96.0) * cast(f32)dots_per_inch)
}

// keys
KEY_BACKSPACE :: cast(u32)win.VK_BACK
KEY_TAB       :: cast(u32)win.VK_TAB
KEY_ESCAPE    :: cast(u32)win.VK_ESCAPE
KEY_ENTER     :: cast(u32)'\r'
KEY_UP        :: cast(u32)win.VK_UP
KEY_DOWN      :: cast(u32)win.VK_DOWN
KEY_LEFT      :: cast(u32)win.VK_LEFT
KEY_RIGHT     :: cast(u32)win.VK_RIGHT
KEY_F1        :: cast(u32)win.VK_F1
KEY_F2        :: cast(u32)win.VK_F2
KEY_F3        :: cast(u32)win.VK_F3
KEY_F4        :: cast(u32)win.VK_F4
KEY_F5        :: cast(u32)win.VK_F5
KEY_F6        :: cast(u32)win.VK_F6
KEY_F7        :: cast(u32)win.VK_F7
KEY_F8        :: cast(u32)win.VK_F8
KEY_F9        :: cast(u32)win.VK_F9
KEY_F10       :: cast(u32)win.VK_F10
KEY_F11       :: cast(u32)win.VK_F11
KEY_LSHIFT    :: cast(u32)win.VK_LSHIFT
KEY_RSHIFT    :: cast(u32)win.VK_RSHIFT
KEY_LCTRL     :: cast(u32)win.VK_LCONTROL
KEY_RCTRL     :: cast(u32)win.VK_RCONTROL
KEY_DELETE    :: cast(u32)win.VK_DELETE
KEY_A         :: cast(u32)'A'
KEY_B         :: cast(u32)'B'
KEY_C         :: cast(u32)'C'
KEY_D         :: cast(u32)'D'
KEY_E         :: cast(u32)'E'
KEY_F         :: cast(u32)'F'
KEY_G         :: cast(u32)'G'
KEY_H         :: cast(u32)'H'
KEY_I         :: cast(u32)'I'
KEY_J         :: cast(u32)'J'
KEY_K         :: cast(u32)'K'
KEY_L         :: cast(u32)'L'
KEY_M         :: cast(u32)'M'
KEY_N         :: cast(u32)'N'
KEY_O         :: cast(u32)'O'
KEY_P         :: cast(u32)'P'
KEY_Q         :: cast(u32)'Q'
KEY_R         :: cast(u32)'R'
KEY_S         :: cast(u32)'S'
KEY_T         :: cast(u32)'T'
KEY_U         :: cast(u32)'U'
KEY_V         :: cast(u32)'V'
KEY_W         :: cast(u32)'W'
KEY_X         :: cast(u32)'X'
KEY_Y         :: cast(u32)'Y'
KEY_Z         :: cast(u32)'Z'
