package transmission_project

import "core:os"
import "core:fmt"
import "core:time"

import "fenster"
import "wav"
import "iio"

main :: proc() {
	level := uint(10)
	bin_size := uint(1 << level)
	sample_rate :: 60_000_000
	focus_freq := 100_000_000
	history_size :: 800

	info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sample_rate, int(bin_size))
	if !info.success do return
//	defer iio.undo_device(&info)

	using fenster
	scr_buf := make([]rgba, bin_size*history_size)
	f_actual := Fenster{
		title = "waterfall",
		width = i32(bin_size),
		height = i32(history_size),
		buf = raw_data(scr_buf)
	}
	fen := &f_actual
	fenster.open(fen)
	defer {
		fenster.close(fen)
		delete(scr_buf)
	}

	signal_buffer := wav.Audio{sample_rate/10_000, make([]f32, bin_size)}
	freqi_buffer := make([]complex64, bin_size)
	freqs_buffer := make([]f32, bin_size)
	defer {
		delete(signal_buffer.audio)
		delete(freqi_buffer)
		delete(freqs_buffer)
	}

	arrow_was_pressed := false
	space_was_pressed := false
	paused := false
	for !fenster.loop(fen) {
		if !paused do for y := fen.height - 1;  y > 0 ; y -= 1 {
			this_line := scr_buf[fen.width*y : fen.width*(y+1)]
			next_line := scr_buf[fen.width*(y-1) : fen.width*y]
			copy(this_line, next_line)
		}
		data := iio.refill_buffer(&info)
//		for q, i in data do signal_buffer.audio[i] = math.atan2(f32(q[0])/wav.MAX_U15, f32(q[1])/wav.MAX_U15)
		fted := fft(data, level, freqi_buffer, freqs_buffer)
		{
			maxf: f32
			for f, i in fted do if f > maxf do maxf = f
			for f, i in fted {
				fen.buf[i] = mono_colour(u8(255*f/maxf))
			}
		}

		/* coloured subdivisions */
		{
			for k: uint = bin_size >> 2; k < bin_size; k += (bin_size >> 2){
				x := int(k)
				y := history_size - 20
				fen.buf[x + int(fen.width)*y] = fenster.RED
			}
			for k: uint = bin_size >> 3; k < bin_size; k += (bin_size >> 2){
				x := int(k)
				y := history_size - 10
				fen.buf[x + int(fen.width)*y] = fenster.RED
			}
			for k: uint = bin_size >> 4; k < bin_size; k += (bin_size >> 3){
				x := int(k)
				y := history_size - 5
				fen.buf[x + int(fen.width)*y] = fenster.BLUE
			}
			for k: uint = bin_size >> 5; k < bin_size; k += (bin_size >> 4){
				x := int(k)
				y := history_size - 5
				fen.buf[x + int(fen.width)*y] = fenster.GREEN
			}
		}

		arrow_pressed := false
		space_pressed := false
		freq_jump := 0
		if fen.keys[ARROW_KEY.UP] {
			arrow_pressed = true
			freq_jump = 10_000_000
		}
		if fen.keys[ARROW_KEY.DOWN] {
			arrow_pressed = true
			freq_jump = -10_000_000
		}
		if fen.keys[SPACE_KEY] {
			space_pressed = true
		}
		if space_pressed && !space_was_pressed do paused = !paused

		if arrow_pressed && !arrow_was_pressed {
			focus_freq += freq_jump
			fmt.printf("new center frequency: %d MHz...", focus_freq/1_000_000)
//			iio.undo_device(&info) /* this crashes, so it's commented out for now, even though it leaks memory */
			info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sample_rate, int(bin_size))
			if !info.success {
				fmt.printf(" failed :(\n")
				return
			}
			fmt.printf(" success!\n")
		}

		arrow_was_pressed = arrow_pressed
		space_was_pressed = space_pressed

		if fen.keys[ESC_KEY] || fen.keys['Q'] do break
	}

}

/* TODO: make a function that displays the frequency of the top N amount of peaks, preferably all main 'harmonics' */
peak :: proc(fted: wav.Audio) -> (peak_freq: f32, peak_index: int) {
	maxf: f32
	maxi: int
	for f, i in fted.audio do if f > maxf { maxf = f; maxi = i }
	return f32(maxi)*f32(fted.sample_freq)/f32(len(fted.audio)), maxi
}

fft :: proc{ complex_fft, real_fft }

/* this takes two-channel input data and does the casting to float and such all by itself */
complex_fft :: proc(a: [][2]i16, power: uint, freqsi: []complex64 = nil, freqs: []f32 = nil) -> []f32 {
	freqsi := freqsi; freqs := freqs
	bin_size := uint(1 << power)
	assert(bin_size <= uint(len(a)))

	new_freqsi := freqsi == nil
	if new_freqsi do freqsi = make([]complex64, bin_size)
	defer if new_freqsi do delete(freqsi)

	for it in 0..<bin_size {
		freqsi[bit_reverse(it, power)] = complex(f32(a[it][0])/wav.MAX_U15, f32(a[it][1])/wav.MAX_U15)
	}
	// https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
	for step in 1..=uint(power) {
		N := 1 << step
		w_N := expi(-math.TAU/f32(N))
		for it := 0; it < int(bin_size); it += N {
			w_p := complex64(1)
			for k in 0..<N/2 {
				E := freqsi[it + k]
				O := w_p*freqsi[it + k + N/2]
				freqsi[it + k] = E + O
				freqsi[it + k + N/2] = E - O
				w_p = w_p*w_N
			}
		}
	}

	if freqs == nil do freqs = make([]f32, bin_size)
	for i in 0..<bin_size {
		freqs[(i + bin_size/2) % bin_size] = abs(freqsi[i])
	}
	return freqs
}

/* this returns a halfsized fft, since the fft of a real signal produces a perfectly mirrored result */
real_fft :: proc(a: wav.Audio, power: uint, freqsi: []complex64 = nil, freqs: []f32 = nil) -> wav.Audio {
	freqsi := freqsi; freqs := freqs
	bin_size := uint(1 << power)
	assert(bin_size <= uint(len(a.audio)))

	new_freqsi := freqsi == nil
	if new_freqsi do freqsi = make([]complex64, bin_size)
	defer if new_freqsi do delete(freqsi)

	for it in 0..<bin_size {
		freqsi[bit_reverse(it, power)] = complex(a.audio[it], 0)
	}
	// https://en.wikipedia.org/wiki/Cooley%E2%80%93Tukey_FFT_algorithm
	for step in 1..=uint(power) {
		N := 1 << step
		w_N := expi(-math.TAU/f32(N))
		for it := 0; it < int(bin_size); it += N {
			w_p := complex64(1)
			for k in 0..<N/2 {
				E := freqsi[it + k]
				O := w_p*freqsi[it + k + N/2]
				freqsi[it + k] = E + O
				freqsi[it + k + N/2] = E - O
				w_p = w_p*w_N
			}
		}
	}

	if freqs == nil do freqs = make([]f32, bin_size/2) /* we do half, cus it's mirrored past the middle for real values */
	for i in 0..<bin_size/2 {
		freqs[i] = abs(freqsi[i])
	}
	return wav.Audio{ a.sample_freq/2, freqs }	
}

bit_reverse :: proc(n: uint, power: uint) -> (reversed: uint) {
	assert(power < 64)
	for i in 0..<power {
		bit := ((1 << i) & n) >> i
		reversed |= bit << (power - i - 1)
	}
	return reversed
}

/* slow fourier transform */
sft :: proc(a: wav.Audio) -> wav.Audio {
	freqs := make([]f32, len(a.audio)/2) /* we do half, cus it's mirrored past the middle for real values */
	N := f32(len(a.audio))
	for freq, k in &freqs {
		X: complex64
		for x, n in a.audio {
			X += complex(x, 0) * expi(math.TAU*f32(n*k)/N)
		}
		freq = abs(X)
		fmt.println(k)
	}
	return wav.Audio{ a.sample_freq/2, freqs }
}

import "core:math"
expi :: #force_inline proc(p: f32) -> complex64 {
	return complex(math.cos_f32(p), math.sin_f32(p))
}
