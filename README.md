# Waterfall
A waterfall spectrum analyzer for the ADALM-PLUTO SDR, written in Odin, using fenster and libiio. Only on X11 (for now?).
This is a project that was made for the University of Twente First year's Electrical Engineering Wireless transmission project of 2023.

![Mobile data LTE bands around 800MHz](/LTE_bands.png "A picture of the LTE bands in the program")\
*Mobile data LTE bands around 800MHz*\
\
[![Youtube Video demonstration](http://img.youtube.com/vi/S-KG5fY48GU/0.jpg)](http://www.youtube.com/watch?v=S-KG5fY48GU "Demonstration of Waterfall")\
*Video demonstration of Waterfall on YouTube (click for the video)*

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
Pressing the left-and-right arrow keys changes the sampling rate (and with it, the bandwidth of the FFT).\
Holding shift while pressing the arrow keys makes it take smaller steps.\
\
When running the program, there are two optional command-line arguments. The first is the 'level', which dictates the screen size and FFT bin size.
The second is the screen height, so the amount of history the program displays.\
\
Clicking at a spot in the window will print the frequency at the cursor.

## Details
The sample rate seems to be directly proportional to the bandwidth of the signal. At a sample rate of 60MSPS and a focus frequency of 100MHz,
I suspect the frequency at the left of the screen is 70MHz, and the one on the right 130MHz (confirmed with experimentation).\
Every frame is normalized, so if there's no one loud signal, you will see a lot of noise.\
In this repo, there are functions for reading and writing .WAV files, which can be implemented quite easily.\
There is currently a memory leak and more wierdness going on with closing the device and destroying the buffer. I am not sure why it won't destroy the buffer properly.
