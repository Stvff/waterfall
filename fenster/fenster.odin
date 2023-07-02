package fenster

RED         :: rgba{0x00, 0x00, 0xFF, 0xFF}
GREEN       :: rgba{0x00, 0xFF, 0x00, 0xFF}
BLUE        :: rgba{0xFF, 0x00, 0x00, 0xFF}
WHITE       :: rgba{0xFF, 0xFF, 0xFF, 0xFF}
BLACK       :: rgba{0x00, 0x00, 0x00, 0xFF}
PASTEL_RED  :: rgba{0x40, 0x40, 0xFF, 0xFF}
PASTEL_PINK :: rgba{0xB8, 0xA9, 0xF5, 0xFF}
PASTEL_BLUE :: rgba{0xFA, 0xCE, 0x5B, 0xFF}

ARROW_KEY :: enum {UP = 17, DOWN, LEFT, RIGHT}
MOD_KEY :: enum {CTLR = 1, SHIFT = 2, ALT = 4, META = 8}
ESC_KEY   :: 27
BACK_KEY  :: 8
TAB_KEY   :: 9
ENTER_KEY :: 10
DEL_KEY   :: 127
SPACE_KEY :: 32

rgba :: [4]byte
Fenster :: struct {
	title: cstring
	width: i32
	height: i32
	buf: [^]rgba
	keys: [256]b32   /* keys are mostly ASCII, but arrows are 17..20 */
	mod: i32         /* mod is 4 bits mask, ctrl=1, shift=2, alt=4, meta=8 */
	x: i32
	y: i32
	mouse: b32
	_dpy: [8]byte // Display *dpy;
	_w: [8]byte   // Window w;
	_gc: [8]byte  // GC gc;
	_img: [8]byte // XImage *img;
}
Texture :: struct {
	w, h: int
	t: []rgba
}

draw_pixel :: proc {
	draw_pixel_v
	draw_pixel_i
}

draw_pixel_v :: proc(f: ^Fenster, p: [2]int, colour: rgba) {
	if int(f.width) <= p.x || p.x < 0 do return
	if int(f.height) <= p.y || p.y < 0 do return
	f.buf[p.x + int(f.width)*p.y] = colour
}

draw_pixel_i :: proc(f: ^Fenster, x, y: int, colour: rgba) {
	if int(f.width) <= x || x < 0 do return
	if int(f.height) <= y || y < 0 do return
	f.buf[x + int(f.width)*y] = colour
}

draw_pixel_alpha :: proc(f: ^Fenster, p: [2]int, colour: rgba) {
	if colour.a == 0 do return
	if int(f.width) <= p.x || p.x < 0 do return
	if int(f.height) <= p.y || p.y < 0 do return
	clr := colour
	if colour.a != 255 {
		a := int(colour.a)
		exist := f.buf[p.x + int(f.width)*p.y]
		clr.x = u8((255 - a)*int(exist.x)/255 + a*int(colour.x)/255)
		clr.y = u8((255 - a)*int(exist.y)/255 + a*int(colour.y)/255)
		clr.z = u8((255 - a)*int(exist.z)/255 + a*int(colour.z)/255)
		clr.a = 255
	}
	f.buf[p.x + int(f.width)*p.y] = clr
}

mono_colour :: proc(clr: u8) -> rgba {
	return rgba{clr, clr, clr, 255}
}

foreign import fenster "fenster.a"
foreign fenster {
	open :: proc "c" (f: ^Fenster) -> b32 ---
	loop :: proc "c" (f: ^Fenster) -> b32 ---
	close :: proc "c" (f: ^Fenster) ---
//	sleep_ms :: proc "c" (ms: i64) ---
//	time :: proc "c" () -> i64 ---
}
