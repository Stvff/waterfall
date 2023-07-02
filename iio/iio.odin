package iio

STANDARD_IP :: "ip:192.168.2.1"

Context_ptr :: distinct rawptr
Buffer_ptr  :: distinct rawptr
Device_ptr  :: distinct rawptr
Channel_ptr :: distinct rawptr

Info :: struct {
	ctx: Context_ptr
	dev: Device_ptr
	buf: Buffer_ptr
	cha: [2]Channel_ptr
	success: b8
}

foreign import iio "iio_odin.a"
foreign iio {
	prep_and_get_device :: proc(ip_string: cstring, rx_freq, sample_freq, buffer_size: int) -> Info ---
	refill_buffer :: proc(info: ^Info) -> [][2]i16 ---
	undo_device :: proc(info: ^Info) ---
}
