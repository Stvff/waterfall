/*
Based on the code found here:
	https://wiki.analog.com/university/tools/pluto/controlling_the_transceiver_and_transferring_data
*/
#include <iio.h>
#include <stdio.h>
#include <assert.h>

typedef struct iio_context* Context_ptr;
typedef struct iio_buffer*  Buffer_ptr;
typedef struct iio_device*  Device_ptr;
typedef struct iio_channel* Channel_ptr;

typedef struct {
	Context_ptr ctx;
	Device_ptr  dev;
	Buffer_ptr  buf;
	Channel_ptr cha[2];
	unsigned char success;
} Info;

/* this should have the same size and format as Odin's slice type */
typedef struct {
	void *dat;
	unsigned long long len;
} Slice;

Info prep_and_get_device(const char *ip_string, ptrdiff_t rx_freq, ptrdiff_t sample_freq, ptrdiff_t buffer_size) {
	Info info = (Info){ NULL };

	info.ctx = iio_create_context_from_uri(ip_string);
	if(!info.ctx){
		perror("\aprep_and_get_device: could not create context\n");
		return (Info){ NULL };
	}

	{
		Device_ptr dev = iio_context_find_device(info.ctx, "ad9361-phy");
		if(!dev){
			iio_context_destroy(info.ctx);
			perror("\aprep_and_get_device: could not find device ad9361-phy\n");
			return (Info){ NULL };
		}

		iio_channel_attr_write_longlong(
			iio_device_find_channel(dev, "altvoltage0", true),
			"frequency",
			rx_freq); /* RX LO frequency 150MHz */ /* was 2.4GHz */
	 	iio_channel_attr_write_longlong(
			iio_device_find_channel(dev, "voltage0", false),
			"sampling_frequency",
			sample_freq); /* RX baseband rate 60 MSPS */ /* was 5 */
	}

	info.dev = iio_context_find_device(info.ctx, "cf-ad9361-lpc");
	if(!info.dev){
		iio_context_destroy(info.ctx);
		perror("\aprep_and_get_device: could not find device cf-ad9361-lpc\n");
		return (Info){ NULL };
	}

	info.cha[0] = iio_device_find_channel(info.dev, "voltage0", 0);
	info.cha[1] = iio_device_find_channel(info.dev, "voltage1", 0);
	iio_channel_enable(info.cha[0]);
	iio_channel_enable(info.cha[1]);

	info.buf = iio_device_create_buffer(info.dev, buffer_size, false);
	if(!info.buf){
		iio_context_destroy(info.ctx);
		return (Info){ NULL };
	}

	info.success = true;
	return info;
}

Slice refill_buffer(Info *info){
	Slice slice = { 0 };
	iio_buffer_refill(info->buf);
	assert(iio_buffer_step(info->buf) == sizeof(signed short[2]) );

	void* start = iio_buffer_first(info->buf, info->cha[0]);
	void* end   = iio_buffer_end  (info->buf);

	ptrdiff_t span = end - start;
	slice.len = span / sizeof(signed short[2]);
	slice.dat = start;
	return slice;
}

/* this functions seems to always cause segfaults, but not calling it causes a memory leak */
void undo_device(Info *info){
	iio_buffer_destroy(info->buf); /* this call to be precise */
	iio_context_destroy(info->ctx);
}

