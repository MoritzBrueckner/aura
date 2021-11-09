package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import dsp.Complex;

import aura.math.FFT;
import aura.threading.BufferCache;
import aura.threading.Message.DSPMessage;
import aura.types.SwapBuffer;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;
import aura.utils.Pointer;

/**
	Calculates the 1D linear convolution of the input with another buffer called
	`impulse`.
**/
class FFTConvolver extends DSP {
	public static inline var NUM_CHANNELS = 2;
	public static inline var FFT_SIZE = 1024;
	static inline var CHUNK_SIZE = Std.int(FFT_SIZE / 2);

	final impulseSwapBuffer: SwapBuffer;
	final impulseTimes: Array<Complex>; // TODO: only one FFT input buffer is required, merge with p_fftTimeBuf
	final impulseFreqs: Vector<Array<Complex>>; // One array per channel

	final p_fftTimeBuf: Pointer<Array<Complex>>;
	final p_fftFreqBuf: Pointer<Array<Complex>>;

	/**
		The part of the last output signal that was longer than the last frame
		buffer and thus overlaps to the next frame. To prevent allocations
		during runtime and to ensure that overlapLast is not longer than one
		FFT segment, the overlap vectors are preallocated to `CHUNK_SIZE - 1`.
		Use `overlapLength` to get the true length.
	**/
	final overlapLast: Vector<Vector<Float>>;
	final overlapLength: Vector<Int>;

	public function new() {
		assert(Error, isPowerOf2(FFT_SIZE), 'FFT_SIZE must be a power of 2, but it is $FFT_SIZE');

		impulseSwapBuffer = new SwapBuffer(CHUNK_SIZE * 2);

		impulseTimes = new Array<Complex>();
		impulseTimes.resize(FFT_SIZE);

		// TODO: is it needed to set this to zero here?
		for (i in 0...impulseTimes.length) {
			impulseTimes[i] = Complex.zero;
		}

		impulseFreqs = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			impulseFreqs[i] = new Array<Complex>();
			impulseFreqs[i].resize(FFT_SIZE);
		}

		p_fftTimeBuf = new Pointer(null);
		p_fftFreqBuf = new Pointer(null);
		if (!BufferCache.getBuffer(TArrayComplex, p_fftTimeBuf, FFT_SIZE)) {
			throw "Could not allocate time-domain buffer";
		}
		if (!BufferCache.getBuffer(TArrayComplex, p_fftFreqBuf, FFT_SIZE)) {
			throw "Could not allocate frequency-domain buffer";
		}

		overlapLast = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			// Max. impulse size is CHUNK_SIZE
			overlapLast[i] = new Vector<Float>(CHUNK_SIZE - 1);
		}
		overlapLength = createEmptyVecI(NUM_CHANNELS);
	}

	public function setImpulse(impulse: Float32Array) {
		assert(Debug, impulse.length <= CHUNK_SIZE, 'Impulse must not be longer than $CHUNK_SIZE');

		// TODO: Resample impulse if necessary

		// TODO: Support stereo impulse buffers

		// Pad impulse response to FFT size
		for (i in 0...impulse.length) {
			impulseTimes[i] = impulse[i];
		}
		for (i in impulse.length...FFT_SIZE) {
			impulseTimes[i] = Complex.zero;
		}

		calculateImpulseFFT(impulseTimes, impulse.length, 0);
		// TODO: stereo
	}

	// TODO: move this into main thread and use swapbuffer for impulseFreqs instead?
	public function updateImpulseFromSwapBuffer(impulseLength: Int, numChannels: Int) {
		impulseSwapBuffer.setReadLock();
		for (i in 0...numChannels) {
			impulseSwapBuffer.read(impulseTimes, CHUNK_SIZE * i, 0, CHUNK_SIZE);
			// Moving thes function into the main thread will also remove the fft
			// calculation while the lock is active, reducing the lock time
			calculateImpulseFFT(impulseTimes, impulseLength, i);
		}
		impulseSwapBuffer.removeReadLock();
	}

	function calculateImpulseFFT(impulseArray: Array<Complex>, impulseLength: Int, channel: Int) {
		fft(impulseArray, impulseFreqs[channel], FFT_SIZE);
		overlapLength[channel] = impulseLength - 1;
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		for (c in 0...NUM_CHANNELS) {
			if (overlapLength[c] == 0) return;
		}
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
					fftFreqBuf[i] *= impulseFreqs[c][i];
				}

				// Transform back into time domain
				ifft(fftFreqBuf, fftTimeBuf, FFT_SIZE);

				// Copy to output
				for (i in 0...CHUNK_SIZE) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] = fftTimeBuf[i].real;
				}

				// Handle overlapping
				// TODO: Correctly handle cases when the impulse changes length
				for (i in 0...overlapLength[c]) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] += overlapLast[c][i];
				}
				for (i in 0...overlapLength[c]) {
					overlapLast[c][i] = fftTimeBuf[CHUNK_SIZE + i].real;
				}
			}
		}
	}

	override function parseMessage(message: DSPMessage) {
		switch (message.id) {
			case SwapBufferReady:
				final data: Array<Int> = cast message.data;
				updateImpulseFromSwapBuffer(data[0], data[1]);

			default:
				super.parseMessage(message);
		}
	}
}
