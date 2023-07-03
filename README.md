# waterfall
A waterfall spectrum analyzer for the ADALM-PLUTO SDR, written in Odin, using fenster and libiio. Only on X11 (for now?).
This is a project that was made for the University of Twente First year's Electrical Engineering Wireless transmission project of 2023.

![Mobile data LTE bands around 800MHz](/LTE_bands "A picture of the LTE bands in the program")\
*Mobile data LTE bands around 800MHz*

## Dependencies
Linux, X11, [Odin](https://github.com/odin-lang/Odin), [libiio](https://github.com/analogdevicesinc/libiio), bash, gcc

## Building and running
First you build it:\
`$ ./make.sh`\
Then, connect the ADALM-PLUTO to your pc.\
Now you can run it:\
`$ ./waterfall`\
It should bring up the window.

## Usage
Pressing the up-and-down arrow keys changes the frequency that the ADALM-PLUTO 'focuses' on, and with it, the center frequency.\
The center frequency is at the middle of the screen.\
\
Pressing the left-and-right arrow keys changes the bandwidth.\
When running the program, there are two optional command-line arguments. The first is the 'level', which dictates the screen size and FFT bin size.
The second is the screen height, so the amount of history the program displays.

## Details
It starts at 100MHz, a sampling rate of 60MHz (whatever that entails exactly), and an FFT bin size of 1024. Every frame is normalized, so if there's no one loud signal, you will see a lot of noise.\
In this repo, there are functions for reading and writing .WAV files, which can be implemented quite easily.\
There is currently a memory leak and more wierdness going on with closing the device and destroying the buffer. I am not sure why it won't destroy the buffer properly.
