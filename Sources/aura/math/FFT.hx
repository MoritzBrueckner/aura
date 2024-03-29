package aura.math;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.types.Complex;
import aura.types.ComplexArray;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;

enum abstract FFTInputType(Int) {
	var RealValuedInput;
	var ComplexValuedInput;
}

/**
	Container for all required buffers for an FFT computation. The input buffers
	can either be real or complex which depends on whether you instantiate an
	`aura.math.FFT.RealValuedFFT` or an `aura.math.FFT.ComplexValuedFFT`.

	Each instance of this class can have multiple input and output buffers whose
	indices have to be passed to the respective FFT functions. It is more
	efficient to use multiple buffers for different FFT calculations with the
	same size instead of multiple instances of this class. The input buffers
	are guaranteed to be zero-initialized.

	Make sure to not use objects of this class in different threads at the same
	time since `FFTBase` is not thread safe!
**/
abstract class FFTBase {
	public final size: Int;
	public final halfSize: Int;

	public final outputBuffers: Vector<ComplexArray>;

	final expRotationStepTable: ComplexArray;

	public inline function new(size: Int, numOutputs: Int) {
		this.size = size;
		this.halfSize = size >>> 1;

		outputBuffers = new Vector(numOutputs);
		for (i in 0...numOutputs) {
			outputBuffers[i] = new ComplexArray(size);
		}

		// Since the calculations for the complex exponential inside a FFT are
		// basically just a rotation around the unit circle with a constant step
		// size that only depends on the layer size, we can precompute the
		// complex rotation steps.
		final numExpTableEntries = log2Unsigned(size);
		expRotationStepTable = new ComplexArray(numExpTableEntries);

		for (halfLayerIdx in 0...numExpTableEntries) {

			final halfLayerSize = exp2(halfLayerIdx);

			// (-2 * Math.PI) / layerSize == -Math.PI / halfLayerSize,
			// so we store values corresponding to each possible halfLayer index
			expRotationStepTable[halfLayerIdx] = Complex.exp(-Math.PI / halfLayerSize);
		}
	}

	public abstract function forwardFFT(inputBufferIndex: Int, outputBufferIndex: Int): Void;
	public abstract function inverseFFT(inputBufferIndex: Int, outputBufferIndex: Int): Void;

	public abstract function getInput(index: Int): Dynamic;
	public inline function getOutput(index: Int): ComplexArray {
		return outputBuffers[index];
	}
}

class RealValuedFFT extends FFTBase {
	public final inputBuffers: Vector<Float32Array>;

	final tmpInputBufferHalf: ComplexArray;
	final tmpOutputBufferHalf: ComplexArray;

	public inline function new(size: Int, numInputs: Int, numOutputs: Int) {
		super(size, numOutputs);

		inputBuffers = new Vector(numInputs);
		for (i in 0...numInputs) {
			inputBuffers[i] = createEmptyF32Array(size);
		}

		tmpInputBufferHalf = new ComplexArray(halfSize);
		tmpOutputBufferHalf = new ComplexArray(halfSize);
	}

	public inline function forwardFFT(inputBufferIndex: Int, outputBufferIndex: Int) {
		realfft(inputBuffers[inputBufferIndex], outputBuffers[outputBufferIndex], tmpInputBufferHalf, tmpOutputBufferHalf, size, expRotationStepTable);
	}

	public inline function inverseFFT(inputBufferIndex: Int, outputBufferIndex: Int) {
		realifft(outputBuffers[outputBufferIndex], inputBuffers[inputBufferIndex], tmpOutputBufferHalf, tmpInputBufferHalf, size, expRotationStepTable);
	}

	public inline function getInput(index: Int): Float32Array {
		return inputBuffers[index];
	}
}

class ComplexValuedFFT extends FFTBase {
	public final inputBuffers: Vector<ComplexArray>;

	public inline function new(size: Int, numInputs: Int, numOutputs: Int) {
		super(size, numOutputs);

		inputBuffers = new Vector(numInputs);
		for (i in 0...numInputs) {
			inputBuffers[i] = new ComplexArray(size);
		}
	}

	public inline function forwardFFT(inputBufferIndex: Int, outputBufferIndex: Int) {
		fft(inputBuffers[inputBufferIndex], outputBuffers[outputBufferIndex], size, expRotationStepTable);
	}

	public inline function inverseFFT(inputBufferIndex: Int, outputBufferIndex: Int) {
		ifft(outputBuffers[outputBufferIndex], inputBuffers[inputBufferIndex], size, expRotationStepTable);
	}

	public inline function getInput(index: Int): ComplexArray {
		return inputBuffers[index];
	}
}

/**
	Calculate the fast fourier transformation of the signal given in `inTimes`
	and output the result in `outFreqs`.

	@param inTimes Input buffer in time domain. Must have length of `size`.
	@param outFreqs Output buffer in frequency domain. Must have length of `size`.
	@param size The size of the FFT. Must be a power of 2.
**/
inline function fft(inTimes: ComplexArray, outFreqs: ComplexArray, size: Int, expRotationStepTable: ComplexArray) {
	ditfft2Iterative(inTimes, outFreqs, size, false, expRotationStepTable);
}

/**
	Calculate the inverse fast fourier transformation of the signal given in
	`inFreqs` and output the result in `outTimes`.

	@param inFreqs Input buffer in frequency domain. Must have length of `size`.
	@param outTimes Output buffer in time domain. Must have length of `size`.
	@param size The size of both buffers. Must be a power of 2.
	@param scale If true, scale output values by `1 / size`.
**/
inline function ifft(inFreqs: ComplexArray, outTimes: ComplexArray, size: Int, expRotationStepTable: ComplexArray, scale = true) {
	ditfft2Iterative(inFreqs, outTimes, size, true, expRotationStepTable);
	if (scale) {
		for (i in 0...size) {
			outTimes[i] = outTimes[i].scale(1 / size);
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
inline function realfft(inTimes: Float32Array, outFreqs: ComplexArray, timeCmplxStore: ComplexArray, freqCmplxStore: ComplexArray, size: Int, expRotationStepTable: ComplexArray) {
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

	fft(timeCmplxStore, freqCmplxStore, halfSize, expRotationStepTable);

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

		final real = xPlus.real + iCos * xPlus.imag - iSin * xMinus.real;
		final imag = xMinus.imag - iSin * xPlus.imag - iCos * xMinus.real;
		outFreqs[i] = new Complex(real, imag);
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
inline function realifft(inFreqs: ComplexArray, outTimes: Float32Array, freqCmplxStore: ComplexArray, timeCmplxStore: ComplexArray, size: Int, expRotationStepTable: ComplexArray) {
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

	ifft(freqCmplxStore, timeCmplxStore, halfSize, expRotationStepTable, false);

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

#if AURA_BACKEND_HL @:hlNative("aura_hl", "ditfft2_iterative") #end
private function ditfft2Iterative(time: ComplexArray, freq: ComplexArray, n: Int, inverse: Bool, expRotationStepTable: ComplexArray) {
	// Decimate
	final log2N = log2Unsigned(n);
	for (i in 0...n) {
		final reversedI = bitReverseUint32(i, log2N);

		if (reversedI > i) {
			freq[i] = time[reversedI];
			freq[reversedI] = time[i];
		}
		else if (reversedI == i) {
			freq[i] = time[reversedI];
		}
	}

	var layerSize = 2; // Size of the FFT for the current layer in the divide & conquer tree
	var halfLayerIdx = 0;
	while (layerSize <= n) { // Iterate over all layers beginning with the lowest
		final halfLayerSize = layerSize >>> 1;

		final expRotationStep = expRotationStepTable[halfLayerIdx].copy();
		if (inverse) {
			expRotationStep.setFrom(expRotationStep.conj());
		}

		var sectionOffset = 0;
		while (sectionOffset < n) {
			final currentExpRotation = new Complex(1.0, 0.0);

			for (i in 0...halfLayerSize) {
				final even = freq[sectionOffset + i].copy();
				final odd = freq[sectionOffset + i + halfLayerSize];
				final twiddle = currentExpRotation * odd;

				freq[sectionOffset + i]                 = even + twiddle;
				freq[sectionOffset + i + halfLayerSize] = even - twiddle;

				currentExpRotation.setFrom(currentExpRotation * expRotationStep);
			}

			sectionOffset += layerSize;
		}

		layerSize <<= 1;
		halfLayerIdx++;
	}
}

// The following bit reversal code was taken (and slightly altered) from
// https://graphics.stanford.edu/~seander/bithacks.html#BitReverseTable.
// The original sources are released in the public domain.

// Bit reversal LUT where each entry is one possible byte (value = address)
private final bitReverseTable: kha.arrays.Uint8Array = uint8ArrayFromIntArray([
	0x00, 0x80, 0x40, 0xC0, 0x20, 0xA0, 0x60, 0xE0, 0x10, 0x90, 0x50, 0xD0, 0x30, 0xB0, 0x70, 0xF0,
	0x08, 0x88, 0x48, 0xC8, 0x28, 0xA8, 0x68, 0xE8, 0x18, 0x98, 0x58, 0xD8, 0x38, 0xB8, 0x78, 0xF8,
	0x04, 0x84, 0x44, 0xC4, 0x24, 0xA4, 0x64, 0xE4, 0x14, 0x94, 0x54, 0xD4, 0x34, 0xB4, 0x74, 0xF4,
	0x0C, 0x8C, 0x4C, 0xCC, 0x2C, 0xAC, 0x6C, 0xEC, 0x1C, 0x9C, 0x5C, 0xDC, 0x3C, 0xBC, 0x7C, 0xFC,
	0x02, 0x82, 0x42, 0xC2, 0x22, 0xA2, 0x62, 0xE2, 0x12, 0x92, 0x52, 0xD2, 0x32, 0xB2, 0x72, 0xF2,
	0x0A, 0x8A, 0x4A, 0xCA, 0x2A, 0xAA, 0x6A, 0xEA, 0x1A, 0x9A, 0x5A, 0xDA, 0x3A, 0xBA, 0x7A, 0xFA,
	0x06, 0x86, 0x46, 0xC6, 0x26, 0xA6, 0x66, 0xE6, 0x16, 0x96, 0x56, 0xD6, 0x36, 0xB6, 0x76, 0xF6,
	0x0E, 0x8E, 0x4E, 0xCE, 0x2E, 0xAE, 0x6E, 0xEE, 0x1E, 0x9E, 0x5E, 0xDE, 0x3E, 0xBE, 0x7E, 0xFE,
	0x01, 0x81, 0x41, 0xC1, 0x21, 0xA1, 0x61, 0xE1, 0x11, 0x91, 0x51, 0xD1, 0x31, 0xB1, 0x71, 0xF1,
	0x09, 0x89, 0x49, 0xC9, 0x29, 0xA9, 0x69, 0xE9, 0x19, 0x99, 0x59, 0xD9, 0x39, 0xB9, 0x79, 0xF9,
	0x05, 0x85, 0x45, 0xC5, 0x25, 0xA5, 0x65, 0xE5, 0x15, 0x95, 0x55, 0xD5, 0x35, 0xB5, 0x75, 0xF5,
	0x0D, 0x8D, 0x4D, 0xCD, 0x2D, 0xAD, 0x6D, 0xED, 0x1D, 0x9D, 0x5D, 0xDD, 0x3D, 0xBD, 0x7D, 0xFD,
	0x03, 0x83, 0x43, 0xC3, 0x23, 0xA3, 0x63, 0xE3, 0x13, 0x93, 0x53, 0xD3, 0x33, 0xB3, 0x73, 0xF3,
	0x0B, 0x8B, 0x4B, 0xCB, 0x2B, 0xAB, 0x6B, 0xEB, 0x1B, 0x9B, 0x5B, 0xDB, 0x3B, 0xBB, 0x7B, 0xFB,
	0x07, 0x87, 0x47, 0xC7, 0x27, 0xA7, 0x67, 0xE7, 0x17, 0x97, 0x57, 0xD7, 0x37, 0xB7, 0x77, 0xF7,
	0x0F, 0x8F, 0x4F, 0xCF, 0x2F, 0xAF, 0x6F, 0xEF, 0x1F, 0x9F, 0x5F, 0xDF, 0x3F, 0xBF, 0x7F, 0xFF
]);

/**
	Return the reversed bits of the given `value`, where `log2N` is the position
	of the most significant bit that should be used for the left bound of the
	"reverse range".
**/
private inline function bitReverseUint32(value: Int, log2N: Int): Int {
	return (
		(bitReverseTable[ value         & 0xff] << 24) |
		(bitReverseTable[(value >>> 8 ) & 0xff] << 16) |
		(bitReverseTable[(value >>> 16) & 0xff] << 8 ) |
		(bitReverseTable[(value >>> 24) & 0xff]      )
	) >>> (32 - log2N);
}

private inline function uint8ArrayFromIntArray(array: Array<Int>): kha.arrays.Uint8Array {
	final out = new kha.arrays.Uint8Array(array.length);
	for (i in 0...array.length) {
		out[i] = array[i];
	}
	return out;
}
