package aura.dsp;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.Float32Array;
import kha.arrays.Int32Array;

import aura.math.FFT;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.types.ComplexArray;
import aura.types.SwapBuffer;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;
import aura.utils.Profiler;

/**
	Calculates the 1D linear convolution of the input with another buffer called
	`impulse`.
**/
class FFTConvolver extends DSP {
	public static inline var NUM_CHANNELS = 2;
	public static inline var FFT_SIZE = 1024;
	public static inline var CHUNK_SIZE = Std.int(FFT_SIZE / 2);

	/**
		The amount of samples used to (temporally) interpolate
		between consecutive impulse responses. Values larger than `CHUNK_SIZE`
		are clamped to that length.

		**Special values**:
		- Any negative value: Automatically follows `CHUNK_SIZE`
		- 0: Do not interpolate between consecutive impulse responses // TODO implement me
	**/
	// TODO: make thread-safe
	public var temporalInterpolationLength = -1;

	final impulseSwapBuffer: SwapBuffer;

	/**
		The part of the last output signal that was longer than the last frame
		buffer and thus overlaps to the next frame. To prevent allocations
		during runtime and to ensure that overlapPrev is not longer than one
		FFT segment, the overlap vectors are preallocated to `CHUNK_SIZE - 1`.
		Use `overlapLength` to get the true length.
	**/
	final overlapPrev: Vector<Vector<FastFloat>>;

	/**
		The (per-channel) overlap length of the convolution result for the
		current impulse response.
	**/
	final overlapLength: Vector<Int>;

	/**
		The (per-channel) overlap length of the convolution result for the
		impulse response from the previous processing block.
	**/
	final prevOverlapLength: Vector<Int>;

	static var signalFFT: Null<RealValuedFFT>;
	final impulseFFT: Null<RealValuedFFT>;

	var currentImpulseAlternationIndex = 0;
	final prevImpulseLengths: Int32Array = new Int32Array(NUM_CHANNELS);

	public function new() {
		assert(Error, isPowerOf2(FFT_SIZE), 'FFT_SIZE must be a power of 2, but it is $FFT_SIZE');

		if (signalFFT == null) {
			signalFFT = new RealValuedFFT(FFT_SIZE, 2, 2);
		}
		impulseFFT = new RealValuedFFT(FFT_SIZE, 1, NUM_CHANNELS * 2);

		prevImpulseLengths = new Int32Array(NUM_CHANNELS);
		for (i in 0...prevImpulseLengths.length) {
			prevImpulseLengths[i] = 0;
		}

		impulseSwapBuffer = new SwapBuffer(CHUNK_SIZE * 2);

		overlapPrev = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			// Max. impulse size is CHUNK_SIZE
			overlapPrev[i] = new Vector<FastFloat>(CHUNK_SIZE - 1);
		}
		overlapLength = createEmptyVecI(NUM_CHANNELS);
		prevOverlapLength = createEmptyVecI(NUM_CHANNELS);
	}

	public function setImpulse(impulse: Float32Array) {
		assert(Debug, impulse.length <= CHUNK_SIZE, 'Impulse must not be longer than $CHUNK_SIZE');

		// TODO: Resample impulse if necessary

		// TODO: Support stereo impulse buffers

		final impulseTimeDomain = impulseFFT.getInput(0);

		// Pad impulse response to FFT size
		for (i in 0...impulse.length) {
			impulseTimeDomain[i] = impulse[i];
		}
		for (i in impulse.length...FFT_SIZE) {
			impulseTimeDomain[i] = 0.0;
		}

		calculateImpulseFFT(impulseTimeDomain, impulse.length, 0);
	}

	// TODO: move this into main thread and use swapbuffer for impulse freqs
	// instead? Moving the impulse FFT computation into the main thread will
	// also remove the fft computation while the swap buffer lock is active,
	// reducing the lock time, but it occupies the main thread more...
	function updateImpulseFromSwapBuffer(impulseLengths: Array<Int>) {
		final impulseTimeDomain = impulseFFT.getInput(0);

		impulseSwapBuffer.beginRead();
		for (c in 0...impulseLengths.length) {
			impulseSwapBuffer.read(impulseTimeDomain, 0, CHUNK_SIZE * c, CHUNK_SIZE);
			inline calculateImpulseFFT(impulseTimeDomain, impulseLengths[c], c);
		}
		impulseSwapBuffer.endRead();
		currentImpulseAlternationIndex = 1 - currentImpulseAlternationIndex;
	}

	inline function calculateImpulseFFT(impulseArray: Float32Array, impulseLength: Int, channelIndex: Int) {
		impulseFFT.forwardFFT(0, NUM_CHANNELS * channelIndex + currentImpulseAlternationIndex);

		overlapLength[channelIndex] = maxI(prevImpulseLengths[channelIndex], impulseLength - 1);
		prevImpulseLengths[channelIndex] = impulseLength;
	}

	public function process(buffer: AudioBuffer) {
		Profiler.event();

		// TODO
		assert(Critical, buffer.numChannels == NUM_CHANNELS);

		for (c in 0...buffer.numChannels) {
			if (overlapLength[c] <= 0) return;
		}

		// Ensure correct boundaries
		final isMultiple = (buffer.channelLength % CHUNK_SIZE) == 0 || (CHUNK_SIZE % buffer.channelLength) == 0;
		assert(Debug, isMultiple, "channelLength must be a multiple of CHUNK_SIZE or vice versa");

		var numSegments: Int; // Segments per channel frame
		var segmentSize: Int;
		if (CHUNK_SIZE < buffer.channelLength) {
			numSegments = Std.int(buffer.channelLength / CHUNK_SIZE);
			segmentSize = CHUNK_SIZE;
		}
		else {
			// TODO: accumulate samples if buffer.channelLength < CHUNK_SIZE,
			//  then delay output
			numSegments = 1;
			segmentSize = buffer.channelLength;
		}

		final numInterpolationSteps = temporalInterpolationLength < 0 ? CHUNK_SIZE : minI(temporalInterpolationLength, CHUNK_SIZE);
		final interpolationStepSize = 1 / numInterpolationSteps;

		final signalTimeDomainCurrentImpulse = signalFFT.getInput(0);
		final signalTimeDomainPrevImpulse = signalFFT.getInput(1);
		final signalFreqDomainCurrentImpulse = signalFFT.getOutput(0);
		final signalFreqDomainPrevImpulse = signalFFT.getOutput(1);

		for (c in 0...buffer.numChannels) {
			final channelView = buffer.getChannelView(c);

			final impulseFreqDomainCurrent = impulseFFT.getOutput(NUM_CHANNELS * c + currentImpulseAlternationIndex);
			final impulseFreqDomainPrev = impulseFFT.getOutput(NUM_CHANNELS * c + (1 - currentImpulseAlternationIndex));

			for (s in 0...numSegments) {
				final segmentOffset = s * segmentSize;

				// Copy to FFT input buffer and apply padding
				for (i in 0...segmentSize) {
					signalTimeDomainCurrentImpulse[i] = channelView[segmentOffset + i];
				}
				for (i in segmentSize...FFT_SIZE) {
					signalTimeDomainCurrentImpulse[i] = 0.0;
				}

				signalFFT.forwardFFT(0, 0);

				// Copy signal frequency signal to multiply with
				// both current and previous impulse frequency responses
				signalFreqDomainPrevImpulse.copyFrom(signalFreqDomainCurrentImpulse);

				// The actual convolution takes place here
				// TODO: SIMD
				for (i in 0...FFT_SIZE) {
					signalFreqDomainCurrentImpulse[i] *= impulseFreqDomainCurrent[i];
					signalFreqDomainPrevImpulse[i] *= impulseFreqDomainPrev[i];
				}

				// Transform back into time domain
				signalFFT.inverseFFT(0, 0);
				signalFFT.inverseFFT(1, 1);

				// Interpolate and copy to output
				var t = 1.0;
				for (i in 0...numInterpolationSteps) {
					channelView[segmentOffset + i] = lerpF32(signalTimeDomainPrevImpulse[i], signalTimeDomainCurrentImpulse[i], t);
					t -= interpolationStepSize;
				}
				for (i in numInterpolationSteps...CHUNK_SIZE) {
					channelView[segmentOffset + i] = signalTimeDomainCurrentImpulse[i];
				}

				// Apply overlapping from last segment
				for (i in 0...prevOverlapLength[c]) {
					channelView[segmentOffset + i] += overlapPrev[c][i];
				}
				// Write overlapping samples for next segment
				for (i in 0...overlapLength[c]) {
					overlapPrev[c][i] = signalTimeDomainCurrentImpulse[CHUNK_SIZE + i];
				}
				prevOverlapLength[c] = overlapLength[c];
			}
		}
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			case DSPMessageID.SwapBufferReady:
				updateImpulseFromSwapBuffer(message.data);

			default:
				super.parseMessage(message);
		}
	}
}
