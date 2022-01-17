package aura.math;

import aura.types.Complex;

/**
	Calculate the fast fourier transformation of the signal given in `inTimes`
	and output the result in `outFreqs`.

	@param inTimes Input buffer in time domain. Must have length of `size`.
	@param outFreqs Output buffer in frequency domain. Must have length of `size`.
	@param size The size of both buffers. Must be a power of 2.
**/
inline function fft(inTimes: ComplexArray, outFreqs: ComplexArray, size: Int) {
	ditfft2(inTimes, 0, outFreqs, 0, size, 1, false);
}

/**
	Calculate the inverse fast fourier transformation of the signal given in
	`inFreqs` and output the result in `outTimes`.

	@param inFreqs Input buffer in frequency domain. Must have length of `size`.
	@param outTimes Output buffer in time domain. Must have length of `size`.
	@param size The size of both buffers. Must be a power of 2.
**/
inline function ifft(inFreqs: ComplexArray, outTimes: ComplexArray, size: Int) {
	ditfft2(inFreqs, 0, outTimes, 0, size, 1, true);
	for (i in 0...size) {
		outTimes[i].scale(1 / size);
	}
}

/**
	Modified copy of `dsp.FFT.ditfft2()` from the "hxdsp" library (*) to be able
	to use Aura's own complex number type to make the fft allocation-less.

	The used algorithm is a Radix-2 Decimation-In-Time variant of Cooley–Tukey's
	FFT, recursive.

	(*) https://github.com/baioc/hxdsp, released under the UNLICENSE license.
**/
private function ditfft2(time: ComplexArray, t: Int, freq: ComplexArray, f: Int, n: Int, step: Int, inverse: Bool) {
	if (n == 1) {
		freq[f] = time[t];
	}
	else {
		final halfLen = Std.int(n / 2);
		ditfft2(time, t,        freq, f,           halfLen, step * 2, inverse);
		ditfft2(time, t + step, freq, f + halfLen, halfLen, step * 2, inverse);

		final tExp = ((inverse ? 1 : -1) * 2 * Math.PI) / n;
		for (k in 0...halfLen) {
			final even = freq[f + k].copy();
			final odd  = freq[f + k + halfLen].copy();
			final twiddle = Complex.exp(tExp * k) * odd;
			freq[f + k]           = even + twiddle;
			freq[f + k + halfLen] = even - twiddle;
		}
	}
}
