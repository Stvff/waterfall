package wav

import "core:os"
import "core:fmt"
import "core:slice"

Audio :: struct {
	sample_freq: int, /* samples per second */
	audio: []f32 /* normalized values */
}
Audio_zero :: Audio { 0, nil }

MAX_U15 :: 32767 /* (max_u16 / 2) - 1 */

read_wav :: proc(name: string) -> (Audio, bool) {
	using fmt
	/* read the file */
	file, succes := os.read_entire_file(name)
	if !succes {
		printf("\aread_wav: could not read file '%s'\n", name)
		return Audio_zero, false
	}
	defer delete(file)

	/* verification */
	{ /* "RIFF" and "WAVE" headers verification */
		read: u32

		headers := file[0:12] /* 12 because it's RIFF, integer, WAVE */
		RIFF_dword :[4]byte: "RIFF"
		WAVE_dword :[4]byte: "WAVE"

		set(&read, headers[0:4])
		if read != transmute(u32) RIFF_dword {
			printf("\aread_wav: the file '%v' does not have a RIFF header\n", name)
			return Audio_zero, false
		}
		set(&read, headers[4:8])
		if read + 8 != u32(len(file)) {
			printf("\aread_wav: the file '%v' reported file length (%v bytes) does not match the actual length (%v bytes)\n", name, read + 8, len(file))
			return Audio_zero, false
		}
		set(&read, headers[8:12])
		if read != transmute(u32) WAVE_dword {
			printf("\aread_wav: the file '%v' does not have a WAVE header\n", name)
			return Audio_zero, false
		}
	}

	{ /* "fmt " header */
		read: u32

		fmt_info := file[12:20]
		fmt__dword :[4]byte: "fmt "
		desired_fmt_length :u32: 16

		set(&read, fmt_info[0:4])
		if read != transmute(u32) fmt__dword {
			printf("\aread_wav: the file '%v' does not have an fmt header\n", name)
			return Audio_zero, false
		}
		set(&read, fmt_info[4:8])
		if read != desired_fmt_length {
			printf("\aread_wav: the file '%v' has an unsupported fmt section length (%v bytes)\n", name, read)
			return Audio_zero, false
		}
	}

	channel_amount: u16
	sample_freq: u32
	{ /* fmt header data extraction and verification, it does not verify the byte rate and bytes per block because they are redundant */
		read: u16
		meta_data := file[20:36]

		desired_audio_format :u16: 1 /* this stands for PCM */
		desired_bits_per_sample :u16: 16

		set(&read, meta_data[0:2])
		if read != desired_audio_format {
			printf("\aread_wav: the file '%v' is not a PCM file (its format is %v), which is unsupported\n", name, read)
			return Audio_zero, false
		}
		set(&channel_amount, meta_data[2:4])
		if channel_amount != 1 && channel_amount != 2 {
			printf("\aread_wav: the file '%v' has more than 2 channels (it has %v channels), which is unsupported\n", name, channel_amount)
			return Audio_zero, false
		}
		set(&sample_freq, meta_data[4:8])
		set(&read, meta_data[14:16])
		if read != desired_bits_per_sample {
			printf("\aread_wav: the file '%v' does not have 16-bit samples (it has %v-bit samples), which is unsupported\n", name, read)
			return Audio_zero, false
		}
	}

	data := file[36:]
	for { /* skipping possible unknown sections */
		data_dword :[4]byte: "data"
		if set(u32, data[0:4]) != transmute(u32) data_dword {
			printf("read_wav: skipping unknown section %v...\n", string(data[0:4]))
			skip_val := set(u32, data[4:8]) + 8
			if int(skip_val) >= len(data) {
				printf("\aread_wav: the file '%v' has corrupted or unknown RIFF sections that lead to the end of the file\n", name)
				return Audio_zero, false
			}
			data = data[skip_val:]
			continue
		} else do break
	}
	if rep_data_len := set(u32, data[4:8]); int(rep_data_len) != len(data) - 8 {
		printf("\aread_wav: the file '%v' reported data length (%v bytes) does not match the actual data length (%v bytes)\n", name, rep_data_len, len(data) - 8)
		return Audio_zero, false
	}
	data = data[8:]

	/* data reading */
	audio := make([]f32, len(data)/int(2*channel_amount))
	if channel_amount == 1 {
		pcms := slice.reinterpret([]i16, data)
		for p, i in pcms {
			audio[i] = f32(p)/MAX_U15
			assert(audio[i] < 1.0 || audio[i] > -1.0, "audio was outside the 1 to -1 range")
		}
	} else if channel_amount == 2 {
		pcms := slice.reinterpret([][2]i16, data)
		for p, i in pcms {
			audio[i] = (f32(p[0]) + f32(p[1]))/(2*MAX_U15)
			assert(audio[i] < 1.0 || audio[i] > -1.0, "audio was outside the 1 to -1 range")
		}
	} else do panic("channel_amount is not 1 or 2, how??????")

	return Audio{int(sample_freq), audio}, true

}

write_wav :: proc(name: string, a: Audio, normalize := true) -> bool {
	buffer := make([]byte, 44 + len(a.audio)*size_of(u16))
	defer delete(buffer)

	{ /* header */
		RIFF_dword :[4]byte: "RIFF"
		WAVE_dword :[4]byte: "WAVE"
		fmt__dword :[4]byte: "fmt "
		data_dword :[4]byte: "data"
		fmt_section_size :u32: 16
		bits_per_sample :u16: 16

		set(buffer[0:4], RIFF_dword)
		set(buffer[4:8], u32(len(buffer)) - 8)
		set(buffer[8:12], WAVE_dword)
		set(buffer[12:16], fmt__dword)
		set(buffer[16:20], fmt_section_size)
		set(buffer[20:22], u16(1) /* format is PCM */)
		set(buffer[22:24], u16(1) /* 1 channel */)
		set(buffer[24:28], u32(a.sample_freq))
		set(buffer[28:32], u32(a.sample_freq)*u32(bits_per_sample)/8)
		set(buffer[32:34], bits_per_sample/8)
		set(buffer[34:36], bits_per_sample)
		set(buffer[36:40], data_dword)
		set(buffer[40:44], u32(len(a.audio)*size_of(u16)))
	}

	if normalize {
		maxf: f32
		maxi: int
		for f, i in a.audio do if f > maxf { maxf = f; maxi = i }
		for i in 0..<len(a.audio) do a.audio[i] /= maxf
	}

	data := slice.reinterpret([]i16, buffer[44:])
	for p, i in a.audio {
		data[i] = i16(p*MAX_U15)
	}

	if !os.write_entire_file(name, buffer) {
		fmt.printf("\awrite_wav: the file '%v' could not be written to\n", name)
		return false
	}
	return true
}

/* Vanadis-like set */
@(private)
set :: proc{
	vanadis_set_to_val,
	vanadis_expression_set_to_val,
	vanadis_set_to_array
}
@(private)
vanadis_set_to_val :: proc(des: ^$D, src: []byte) {
	solid: [size_of(D)]byte
	copy(solid[:], src)
	des^ = transmute(D) solid
}
@(private)
vanadis_expression_set_to_val :: proc($T: typeid, src: []byte) -> T {
	solid: [size_of(T)]byte
	copy(solid[:], src)
	return transmute(T) solid
}
@(private)
vanadis_set_to_array :: proc(des: []byte, src: $S) {
	solid: [size_of(S)]byte = transmute([size_of(S)]byte) src
	copy(des, solid[:])
}

