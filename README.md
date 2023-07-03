# waterfall
A waterfall spectrum analyzer for the ADALM-PLUTO, written in Odin, using fenster and libiio. Only on X11 (for now?).
This is a project that was made for the University of Twente First year's Electrical Engineering Wireless transmission project of 2023.

## Dependencies
X11 (so basically, Linux), [Odin](https://github.com/odin-lang/Odin), [libiio](https://github.com/analogdevicesinc/libiio), bash

## Building and running
First you build it:\
`$ ./make.sh`\
Then you can run it:\
`$ ./waterfall`\
It should bring up the window. Running it in the terminal is highly recommended.

## Usage
The middle of the screen is the '0-frequency' of the complex fourier transform. Pressing the up-and-down arrow keys changes the frequency that the ADALM 'focuses' on.
How to actually interpret that is unclear, but I suspect it changes the center frequency as well.

## Details
It starts at 100MHz, a sampling rate of 60MHz (whatever that entails exactly), and an FFT bin size of 1024.\
In this repo, there are functions for reading and writing .WAV files, which can be implemented quite easily.\
There is currently a memory leak and more wierdness going on with closing the device and destroying the buffer. I am not sure why it won't destroy the buffer properly.
