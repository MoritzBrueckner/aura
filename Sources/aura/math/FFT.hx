package aura.math;

import dsp.Complex;

/**
	Allocation-free version of `dsp.FFT.fft()`.

	@param input Input buffer in time domain. Must have length of `size`.
	@param output Output buffer in frequency domain. Must have length of `size`.
	@param size The size of both buffers. Must be a power of 2.
**/
inline function fft(input: Array<Complex>, output: Array<Complex>, size: Int) {
	@:privateAccess dsp.FFT.ditfft2(input, 0, output, 0, size, 1, false);
	// We're only interested in the positive frequencies, see
	// implementation of FFT.rfft() for reference
	for (i in Std.int(size / 2)...size) {
		output[i] = 0;
	}
}

/**
	Allocation-free version of `dsp.FFT.ifft()`.

	@param input Input buffer in frequency domain. Must have length of `size`.
	@param output Output buffer in time domain. Must have length of `size`.
	@param size The size of both buffers. Must be a power of 2.
**/
inline function ifft(input: Array<Complex>, output: Array<Complex>, size: Int) {
	@:privateAccess dsp.FFT.ditfft2(input, 0, output, 0, size, 1, true);
	for (i in 0...size) {
		output[i] = output[i].scale(1 / size);
	}
}

/**
	Finds the power of 2 that is equal to or greater than the given natural.
**/
inline function nextPow2(x: Int): Int {
	return @:privateAccess dsp.FFT.nextPow2(x);
}
