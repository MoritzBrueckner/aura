package aura.math;

import kha.arrays.Float32Array;

import aura.types.Complex;
import aura.types.ComplexArray;

/**
	Calculate the fast fourier transformation of the signal given in `inTimes`
	and output the result in `outFreqs`.

	@param inTimes Input buffer in time domain. Must have length of `size`.
	@param outFreqs Output buffer in frequency domain. Must have length of `size`.
	@param size The size of the FFT. Must be a power of 2.
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
	@param scale If true, scale output values by `1 / size`.
**/
inline function ifft(inFreqs: ComplexArray, outTimes: ComplexArray, size: Int, scale = true) {
	ditfft2(inFreqs, 0, outTimes, 0, size, 1, true);
	if (scale) {
		for (i in 0...size) {
			outTimes[i].scale(1 / size);
		}
	}
}

/**
	Variant of `aura.math.fft` with real-valued input, almost double as fast as
	its complex-input counterpart.

	@param inTimes Input buffer in time domain. Must have length of `size`.
	@param outFreqs Output buffer in frequency domain. Must have length of `size`.
	@param timeCmplxStore Temporary buffer. May contain any values and will contain garbage values afterwards. Must have length of `Std.int(size / 2)`.
	@param freqCmplxStore Temporary buffer. May contain any values and will contain garbage values afterwards. Must have length of `Std.int(size / 2)`.
	@param size The size of the FFT. Must be a power of 2.
**/
inline function realfft(inTimes: Float32Array, outFreqs: ComplexArray, timeCmplxStore: ComplexArray, freqCmplxStore: ComplexArray, size: Int) {
	// Reference:
	// Lyons, Richard G. (2011). Understanding Digital Signal Processing,
	//     3rd edn. pp. 694–696 (Section 13.5.2: Performing a 2N-Point Real FFT)

	final halfSize = Std.int(size / 2);
	assert(Error, inTimes.length == size);
	assert(Error, outFreqs.length == size);
	assert(Error, timeCmplxStore.length == halfSize);
	assert(Error, freqCmplxStore.length == halfSize);

	for (i in 0...halfSize) {
		timeCmplxStore[i] = new Complex(inTimes[2 * i], inTimes[2 * i + 1]);
	}

	fft(timeCmplxStore, freqCmplxStore, halfSize);

	final piN = Math.PI / halfSize;

	// Construct first half of the result
	for (i in 0...halfSize) {
		final opp = (i == 0) ? freqCmplxStore[i] : freqCmplxStore[halfSize - i];

		final xPlus = new Complex(
			0.5 * (freqCmplxStore[i].real + opp.real),
			0.5 * (freqCmplxStore[i].imag + opp.imag)
		);
		final xMinus = new Complex(
			0.5 * (freqCmplxStore[i].real - opp.real),
			0.5 * (freqCmplxStore[i].imag - opp.imag)
		);

		final piNi = piN * i;
		final iSin = Math.sin(piNi);
		final iCos = Math.cos(piNi);
		outFreqs[i].real = xPlus.real + iCos * xPlus.imag - iSin * xMinus.real;
		outFreqs[i].imag = xMinus.imag - iSin * xPlus.imag - iCos * xMinus.real;
	}

	outFreqs[halfSize] = freqCmplxStore[0].real - freqCmplxStore[0].imag;

	// Mirror first half to second half of the result
	for (i in halfSize + 1...size) {
		outFreqs[i] = outFreqs[halfSize - 1 - (i - halfSize)].conj();
	}
}

/**
	Variant of `aura.math.ifft` with real-valued output, almost double as fast
	as its complex-input counterpart.

	@param inFreqs Input buffer in frequency domain. Must have length of `size`.
	@param outTimes Output buffer in time domain. Must have length of `size`.
	@param freqCmplxStore Temporary buffer. May contain any values and will contain garbage values afterwards. Must have length of `Std.int(size / 2)`.
	@param timeCmplxStore Temporary buffer. May contain any values and will contain garbage values afterwards. Must have length of `Std.int(size / 2)`.
	@param size The size of the FFT. Must be a power of 2.
**/
inline function realifft(inFreqs: ComplexArray, outTimes: Float32Array, freqCmplxStore: ComplexArray, timeCmplxStore: ComplexArray, size: Int) {
	// Reference:
	// Scheibler, Robin (2013). Real FFT Algorithms.
	//     Available at: http://www.robinscheibler.org/2013/02/13/real-fft.html

	final halfSize = Std.int(size / 2);
	assert(Error, inFreqs.length == size);
	assert(Error, outTimes.length == size);
	assert(Error, freqCmplxStore.length == halfSize);
	assert(Error, timeCmplxStore.length == halfSize);

	final pi2N = (2 * Math.PI) / size;

	// Construct input
	for (i in 0...halfSize) {
		final oppC = ((i == 0) ? inFreqs[i] : inFreqs[halfSize - i]).conj();

		final xEven = 0.5 * (inFreqs[i] + oppC);
		final xOdd = 0.5 * ((inFreqs[i] - oppC) * Complex.exp(i * pi2N));

		freqCmplxStore[i] = xEven + xOdd.multWithI();
	}

	ifft(freqCmplxStore, timeCmplxStore, halfSize, false);

	final scale = 2 / size;
	for (i in 0...halfSize) {
		outTimes[2 * i] = timeCmplxStore[i].real * scale;
		outTimes[2 * i + 1] = timeCmplxStore[i].imag * scale;
	}
}

/**
	Modified copy of `dsp.FFT.ditfft2()` from the "hxdsp" library (*) to be able
	to use Aura's own complex number type to make the fft allocation-free.

	The used algorithm is a Radix-2 Decimation-In-Time variant of Cooley–Tukey's
	FFT, recursive.

	(*) https://github.com/baioc/hxdsp, released under the UNLICENSE license.
**/
#if AURA_BACKEND_HL @:hlNative("aura_hl", "ditfft2") #end
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
