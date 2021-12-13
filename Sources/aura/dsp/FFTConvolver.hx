package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.math.FFT;
import aura.threading.BufferCache;
import aura.threading.Message.DSPMessage;
import aura.types.Complex;
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
	public static inline var CHUNK_SIZE = Std.int(FFT_SIZE / 2);

	final impulseSwapBuffer: SwapBuffer;
	final impulseTimes: ComplexArray; // TODO: only one FFT input buffer is required, merge with p_fftTimeBuf
	final impulseFreqs: Vector<ComplexArray>; // One array per channel

	final fftTimeBuf: ComplexArray;
	final fftFreqBuf: ComplexArray;

	/**
		The part of the last output signal that was longer than the last frame
		buffer and thus overlaps to the next frame. To prevent allocations
		during runtime and to ensure that overlapLast is not longer than one
		FFT segment, the overlap vectors are preallocated to `CHUNK_SIZE - 1`.
		Use `overlapLength` to get the true length.
	**/
	final overlapLast: Vector<Vector<Float>>;

	/**
		The (per-channel) overlap length of the convolution result for the
		current impulse response.
	**/
	final overlapLength: Vector<Int>;

	/**
		The (per-channel) overlap length of the convolution result for the
		impulse response from the previous processing block.
	**/
	final lastOverlapLength: Vector<Int>;

	public function new() {
		assert(Error, isPowerOf2(FFT_SIZE), 'FFT_SIZE must be a power of 2, but it is $FFT_SIZE');

		impulseSwapBuffer = new SwapBuffer(CHUNK_SIZE * 2);

		impulseTimes = new ComplexArray(FFT_SIZE);

		impulseFreqs = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			impulseFreqs[i] = new ComplexArray(FFT_SIZE);
		}

		fftTimeBuf = new ComplexArray(FFT_SIZE);
		fftFreqBuf = new ComplexArray(FFT_SIZE);

		overlapLast = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			// Max. impulse size is CHUNK_SIZE
			overlapLast[i] = new Vector<Float>(CHUNK_SIZE - 1);
		}
		overlapLength = createEmptyVecI(NUM_CHANNELS);
		lastOverlapLength = createEmptyVecI(NUM_CHANNELS);
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
			impulseTimes[i].setZero();
		}

		calculateImpulseFFT(impulseTimes, impulse.length, 0);
		// TODO: stereo
	}

	// TODO: move this into main thread and use swapbuffer for impulseFreqs instead?
	public function updateImpulseFromSwapBuffer(impulseLengths: Array<Int>) {
		impulseSwapBuffer.beginRead();
		for (i in 0...impulseLengths.length) {
			impulseSwapBuffer.read(impulseTimes, 0, CHUNK_SIZE * i, CHUNK_SIZE);
			// Moving thes function into the main thread will also remove the fft
			// calculation while the lock is active, reducing the lock time
			calculateImpulseFFT(impulseTimes, impulseLengths[i], i);
		}
		impulseSwapBuffer.endRead();
	}

	function calculateImpulseFFT(impulseArray: ComplexArray, impulseLength: Int, channel: Int) {
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
					fftTimeBuf[i].setZero();
				}

				fft(fftTimeBuf, fftFreqBuf, FFT_SIZE);

				// The actual convolution takes place here
				for (i in 0...FFT_SIZE) {
					fftFreqBuf[i] *= impulseFreqs[c][i];
				}

				// Transform back into time domain
				ifft(fftFreqBuf, fftTimeBuf, FFT_SIZE);

				// Copy to output
				for (i in 0...CHUNK_SIZE) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] = fftTimeBuf[i].real;
				}

				// Handle overlapping
				for (i in 0...lastOverlapLength[c]) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] += overlapLast[c][i];
				}
				for (i in 0...overlapLength[c]) {
					overlapLast[c][i] = fftTimeBuf[CHUNK_SIZE + i].real;
				}
				lastOverlapLength[c] = overlapLength[c];
			}
		}
	}

	override function parseMessage(message: DSPMessage) {
		switch (message.id) {
			case SwapBufferReady:
				updateImpulseFromSwapBuffer(message.data);

			default:
				super.parseMessage(message);
		}
	}
}
