package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.math.FFT;
import aura.threading.Message.DSPMessage;
import aura.types.ComplexArray;
import aura.types.SwapBuffer;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;

/**
	Calculates the 1D linear convolution of the input with another buffer called
	`impulse`.
**/
class FFTConvolver extends DSP {
	public static inline var NUM_CHANNELS = 2;
	public static inline var FFT_SIZE = 1024;
	public static inline var CHUNK_SIZE = Std.int(FFT_SIZE / 2);

	final impulseSwapBuffer: SwapBuffer;

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

	static var signalFFT: Null<RealValuedFFT>;
	static var impulseFFT: Null<RealValuedFFT>; // TODO: only one set of input and temp channels required, merge with multi-output signalFFT

	public function new() {
		assert(Error, isPowerOf2(FFT_SIZE), 'FFT_SIZE must be a power of 2, but it is $FFT_SIZE');

		if (signalFFT == null) {
			signalFFT = new RealValuedFFT(FFT_SIZE, 1, 1);
		}
		if (impulseFFT == null) {
			impulseFFT = new RealValuedFFT(FFT_SIZE, 1, NUM_CHANNELS);
		}

		impulseSwapBuffer = new SwapBuffer(CHUNK_SIZE * 2);

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

		final impulseInput = impulseFFT.getInput(0);

		// Pad impulse response to FFT size
		for (i in 0...impulse.length) {
			impulseInput[i] = impulse[i];
		}
		for (i in impulse.length...FFT_SIZE) {
			impulseInput[i] = 0.0;
		}

		calculateImpulseFFT(impulseInput, impulse.length, 0);
	}

	// TODO: move this into main thread and use swapbuffer for impulse freqs
	// instead? Moving the impulse FFT computation into the main thread will
	// also remove the fft computation while the swap buffer lock is active,
	// reducing the lock time, but it occupies the main thread more...
	function updateImpulseFromSwapBuffer(impulseLengths: Array<Int>) {
		final impulseInput = impulseFFT.getInput(0);

		impulseSwapBuffer.beginRead();
		for (i in 0...impulseLengths.length) {
			impulseSwapBuffer.read(impulseInput, 0, CHUNK_SIZE * i, CHUNK_SIZE);
			calculateImpulseFFT(impulseInput, impulseLengths[i], i);
		}
		impulseSwapBuffer.endRead();
	}

	inline function calculateImpulseFFT(impulseArray: Float32Array, impulseLength: Int, channel: Int) {
		impulseFFT.forwardFFT(0, channel);
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

		final signalInput = signalFFT.getInput(0);
		final signalOutput = signalFFT.getOutput(0);

		for (c in 0...NUM_CHANNELS) {
			final impulseFreqs = impulseFFT.getOutput(c);

			for (s in 0...numSegments) {
				final segmentOffset = NUM_CHANNELS * s * segmentSize;

				for (i in 0...segmentSize) {
					// Deinterleave and copy to FFT input buffer
					signalInput[i] = buffer[segmentOffset + i * NUM_CHANNELS + c];
				}
				for (i in segmentSize...FFT_SIZE) {
					signalInput[i] = 0;
				}

				signalFFT.forwardFFT(0, 0);

				// The actual convolution takes place here
				for (i in 0...FFT_SIZE) {
					signalOutput[i] *= impulseFreqs[i];
				}

				// Transform back into time domain
				signalFFT.inverseFFT(0, 0);

				// Copy to output
				for (i in 0...CHUNK_SIZE) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] = signalInput[i];
				}

				// Handle overlapping
				for (i in 0...lastOverlapLength[c]) {
					buffer[segmentOffset + i * NUM_CHANNELS + c] += overlapLast[c][i];
				}
				for (i in 0...overlapLength[c]) {
					overlapLast[c][i] = signalInput[CHUNK_SIZE + i];
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
