package transmission_project

import "core:os"
import "core:fmt"
import "core:time"
import "core:strconv"

import "fenster"
import "wav"
import "iio"

main :: proc() {
	waterfall()
}

waterfall :: proc() {
	level := uint(10)
	if len(os.args) > 1 do level = uint(clamp(strconv.atoi(os.args[1]), 3, 12))
	bin_size := uint(1 << level)
	sample_rate := 60_000_000
	focus_freq := 100_000_000
	history_size := 800
	if len(os.args) > 2 do history_size = clamp(strconv.atoi(os.args[2]), 20, 2000)
	fmt.printf("Level: %v (bin size: %v samples)\nCenter frequency: %v MHz\nSample rate/Bandwidth: %v MHz\nHistory size: %v\n", level, bin_size, focus_freq/1_000_000, sample_rate/1_000_000, history_size)

	info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sample_rate, int(bin_size))
	if !info.success do return
//	defer iio.undo_device(&info)

	using fenster
	scr_buf := make([]rgba, bin_size*uint(history_size))
	f_actual := Fenster{
		title = "waterfall",
		width = i32(bin_size),
		height = i32(history_size),
		buf = raw_data(scr_buf)
	}
	fen := &f_actual
	fenster.open(fen)
	defer {
//		fenster.close(fen)
		delete(scr_buf)
	}

	freqi_buffer := make([]complex64, bin_size)
	freqs_buffer := make([]f32, bin_size)
	defer {
		delete(freqi_buffer)
		delete(freqs_buffer)
	}

	arrow_was_pressed := false
	space_was_pressed := false
	f_key_was_pressed := false
	paused := false
	for !fenster.loop(fen) {
		if !paused do for y := fen.height - 1;  y > 0 ; y -= 1 {
			this_line := scr_buf[fen.width*y : fen.width*(y+1)]
			next_line := scr_buf[fen.width*(y-1) : fen.width*y]
			copy(this_line, next_line)
		}
		data := iio.refill_buffer(&info)
		fted := fft(data, level, freqi_buffer, freqs_buffer)
		maxf: f32; maxi: int
		for f, i in fted do if f > maxf { maxf = f; maxi = i }
		for f, i in fted {
			fen.buf[i] = mono_colour(u8(255*f/maxf))
		}

		/* coloured subdivisions */
		{ for x: uint = bin_size >> 2; x < bin_size; x += (bin_size >> 2){
				y := history_size - 20
				fen.buf[int(x) + int(fen.width)*y] = RED }
			for x: uint = bin_size >> 3; x < bin_size; x += (bin_size >> 2){
				y := history_size - 10
				fen.buf[int(x) + int(fen.width)*y] = RED }
			for x: uint = bin_size >> 4; x < bin_size; x += (bin_size >> 3){
				y := history_size - 5
				fen.buf[int(x) + int(fen.width)*y] = BLUE }
			for x: uint = bin_size >> 5; x < bin_size; x += (bin_size >> 4){
				y := history_size - 5
				fen.buf[int(x) + int(fen.width)*y] = GREEN }
		}

		arrow_pressed := false
		space_pressed := false
		f_key_pressed := false
		freq_jump := 0
		rate_jump := 0

		if fen.keys[ARROW_KEY.UP] { arrow_pressed = true
			if fen.mod == i32(MOD_KEY.SHIFT) do freq_jump = 10_000_000
			else do freq_jump = 100_000_000
		}
		if fen.keys[ARROW_KEY.DOWN] { arrow_pressed = true
			if fen.mod == i32(MOD_KEY.SHIFT) do freq_jump = -10_000_000
			else do freq_jump = -100_000_000
		}

		if fen.keys[ARROW_KEY.LEFT] { arrow_pressed = true
			if fen.mod == i32(MOD_KEY.SHIFT) do rate_jump = 1_000_000
			else do rate_jump = 10_000_000
		}
		if fen.keys[ARROW_KEY.RIGHT] { arrow_pressed = true
			if fen.mod == i32(MOD_KEY.SHIFT) do rate_jump = -1_000_000
			else do rate_jump = -10_000_000
		}

		if fen.keys[SPACE_KEY] do space_pressed = true
		if space_pressed && !space_was_pressed do paused = !paused
		if fen.mouse do f_key_pressed = true
		if f_key_pressed && !f_key_was_pressed do fmt.printf("Frequency at cursor: %v MHz\n", (f32(focus_freq) + f32(sample_rate)*(f32(fen.x)/f32(bin_size) - 0.5)) / 1e6)
		if fen.keys['M'] {
			fmt.printf("Maximum value: %v, at %v MHz\n", maxf, (f32(focus_freq) + f32(sample_rate)*(f32(maxi)/f32(bin_size) - 0.5)) / 1e6)
			fen.buf[maxi] = PASTEL_RED
		}

		if arrow_pressed && !arrow_was_pressed {
			/* focus frequency change */
			if freq_jump != 0 {
				focus_freq = clamp(focus_freq + freq_jump, 50_000_000, 3_000_000_000)
				fmt.printf("new center frequency: %d MHz...", focus_freq/1_000_000)
				//iio.undo_device(&info) /* this crashes, so it's commented out for now, even though it leaks memory */
				info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sample_rate, int(bin_size))
				if !info.success {
					fmt.printf(" failed :(\n")
					return
				}
				fmt.printf(" success!\n")
			}
			/* sample rate change */
			if rate_jump != 0 {
				sample_rate = clamp(sample_rate + rate_jump, 10_000_000, 60_000_000)
				fmt.printf("new sample rate: %d MSPS...", sample_rate/1_000_000)
				//iio.undo_device(&info) /* this crashes, so it's commented out for now, even though it leaks memory */
				info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sample_rate, int(bin_size))
				if !info.success {
					fmt.printf(" failed :(\n")
					return
				}
				fmt.printf(" success!\n")
			}
		}

		arrow_was_pressed = arrow_pressed
		space_was_pressed = space_pressed
		f_key_was_pressed = f_key_pressed

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

/* does not work :(
   it's too slow */
decode :: proc() {
	fmt.println("decoding\n")
	level :: uint(9)
	bin_size :: uint(1 << level)
	sdr_sample_rate :: 60_000_000
	focus_freq := 200_000_000

	low_freq :: bin_size/2 - 50
	high_freq :: low_freq + 100
	freq_difference :: high_freq - low_freq
	audio_sample_rate :: 20_000
	seconds :: 4

	info := iio.prep_and_get_device(iio.STANDARD_IP, focus_freq, sdr_sample_rate, int(bin_size))
	if !info.success do return

	big_buf := make([][2]i16, bin_size * audio_sample_rate * seconds)
	slice := big_buf
	for i in 0..<audio_sample_rate*seconds {
		copy(slice[:bin_size], iio.refill_buffer(&info))
		slice = slice[bin_size:]
	}
	fmt.println("saw the thing")

	decoded := wav.Audio{audio_sample_rate, make([]f32, audio_sample_rate*seconds)}
	freqi_buffer := make([]complex64, bin_size)
	freqs_buffer := make([]f32, bin_size)
	defer {
		delete(decoded.audio)
		delete(freqi_buffer)
		delete(freqs_buffer)
	}

	data := big_buf
	for frame in &decoded.audio {
		fted := fft(data[:bin_size], level, freqi_buffer, freqs_buffer)
		{
			maxf: f32
			maxi: int
			for f, i in fted[low_freq:high_freq] do if f > maxf { maxf = f; maxi = i }
			frame = f32(maxi) / f32(freq_difference) - 0.5
			fmt.println(frame)
		}
		data = data[bin_size:]
	}

	wav.write_wav(os.args[1], decoded, false)
}
