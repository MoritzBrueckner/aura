package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import dsp.Complex;

import aura.math.FFT;
import aura.threading.BufferCache;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;
import aura.utils.Pointer;

/**
	Calculates the 1D linear convolution of the input with another buffer called
	`impulse`.
**/
class FFTConvolver implements DSP {
	public static inline var NUM_CHANNELS = 2;
	public static inline var FFT_SIZE = 4096;
	public static inline var CHUNK_SIZE = Std.int(FFT_SIZE / 2);

	var inUse = false;
	var impulse: Float32Array;

	var p_fftTimeBuf: Pointer<Array<Complex>>;
	var p_fftFreqBuf: Pointer<Array<Complex>>;

	/**
		The part of the last output signal that was longer than the last frame
		buffer and thus overlaps to the next frame.
	**/
	var overlapLast: Vector<Array<Float>>;

	var impulseFreqs: Array<Complex>;

	public function new(impulse: Float32Array) {
		assert(Error, isPowerOf2(FFT_SIZE), 'FFT_SIZE must be a power of 2, but it is $FFT_SIZE');

		this.overlapLast = new Vector(NUM_CHANNELS);

		p_fftTimeBuf = new Pointer(null);
		p_fftFreqBuf = new Pointer(null);
		if (!BufferCache.getBuffer(TArrayComplex, p_fftTimeBuf, FFT_SIZE)) {
			throw "Could not allocate time-domain buffer";
		}
		if (!BufferCache.getBuffer(TArrayComplex, p_fftFreqBuf, FFT_SIZE)) {
			throw "Could not allocate frequency-domain buffer";
		}

		impulseFreqs = new Array<Complex>();
		impulseFreqs.resize(FFT_SIZE);

		setImpulse(impulse);
	}

	public function setImpulse(impulse: Float32Array) {
		// This also ensures that overlapLast is not longer than one FFT segment
		assert(Debug, impulse.length <= CHUNK_SIZE, 'Impulse must not be longer than $CHUNK_SIZE');

		// TODO: Resample impulse if necessary

		// TODO: Support stereo impulse buffers

		this.impulse = impulse;

		// Pad impulse response to FFT size
		final impulseArray = new Array<Complex>();
		impulseArray.resize(FFT_SIZE);
		for (i in 0...impulse.length) {
			impulseArray[i] = impulse[i];
		}
		for (i in impulse.length...FFT_SIZE) {
			impulseArray[i] = Complex.zero;
		}

		// Calculate impulse FFT
		// TODO: Mutex?
		fft(impulseArray, impulseFreqs, FFT_SIZE);
		for (i in Std.int(impulseFreqs.length / 2)...impulseFreqs.length) {
			impulseFreqs[i] = 0;
		}

		// Update overlap buffers
		for (i in 0...NUM_CHANNELS) {
			// TODO: Copy last overlap
			overlapLast[i] = createEmptyVecF(impulse.length - 1).toArray();
		}
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		final deinterleavedLength = Std.int(bufferLength / NUM_CHANNELS);

		// Ensure correct boundaries
		final isMultiple = (deinterleavedLength % CHUNK_SIZE) == 0 || (CHUNK_SIZE % deinterleavedLength) == 0;
		assert(Debug, isMultiple, "deinterleavedLength must be a multiple of CHUNK_SIZE or vice versa");

		final fftTimeBuf = p_fftTimeBuf.get();
		final fftFreqBuf = p_fftFreqBuf.get();

		var numSegments: Int; // Segments per deinterleaved frame
		var segmentSize: Int;
		if (CHUNK_SIZE < deinterleavedLength) {
			numSegments = Std.int(deinterleavedLength / CHUNK_SIZE);
			segmentSize = CHUNK_SIZE;
		}
		else {
			// TODO: accumulate samples if deinterleavedLength < CHUNK_SIZE,
			//  then delay output
			numSegments = 1;
			segmentSize = deinterleavedLength;
		}

		for (c in 0...NUM_CHANNELS) {
			for (s in 0...numSegments) {
				final segmentOffset = NUM_CHANNELS * s * segmentSize;
				for (i in 0...segmentSize) {
					// Deinterleave and copy to input buffer
					final real = buffer[segmentOffset + i * NUM_CHANNELS + c];
					fftTimeBuf[i] = Complex.fromReal(real);
				}
				for (i in segmentSize...FFT_SIZE) {
					fftTimeBuf[i] = Complex.zero;
				}

				fft(fftTimeBuf, fftFreqBuf, FFT_SIZE);

				// The actual convolution takes place here
				for (i in 0...CHUNK_SIZE) {
					fftFreqBuf[i] = fftFreqBuf[i] * impulseFreqs[i];
				}

				// Transform back into time domain
				ifft(fftFreqBuf, fftTimeBuf, FFT_SIZE);

				// Copy to output
				for (i in 0...CHUNK_SIZE) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] = fftTimeBuf[i].real;
				}

				// Handle overlapping
				for (i in 0...overlapLast[c].length) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] += overlapLast[c][i];
				}
				for (i in 0...overlapLast[c].length) {
					overlapLast[c][i] = fftTimeBuf[CHUNK_SIZE + i].real;
				}
			}
		}
	}
}
