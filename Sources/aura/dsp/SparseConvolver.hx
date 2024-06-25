package aura.dsp;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.ByteArray;

import aura.types.AudioBuffer;
import aura.utils.CircularBuffer;

/**
	Perform efficient convolution of sparse impulse responses (i.e., impulse
	responses in which most samples have a value of 0).
**/
class SparseConvolver extends DSP {
	static inline var NUM_CHANNELS = 2;

	public final impulseBuffer: SparseImpulseBuffer;

	final delayBufs: Vector<CircularBuffer>;

	/**
		Create a new `SparseConvolver` object.

		@param maxNumImpulses The maximal amount of non-zero impulses that can be stored in `this.impulseBuffer`.
		@param maxNumImpulseResponseSamples The highest possible position of any non-zero impulse stored in the `impulseBuffer`.
			There is no bounds checking in place!
	**/
	public function new(maxNumImpulses: Int, maxNumImpulseResponseSamples: Int) {
		assert(Error, maxNumImpulseResponseSamples > maxNumImpulses);

		impulseBuffer = new SparseImpulseBuffer(maxNumImpulses);

		delayBufs = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			delayBufs[i] = new CircularBuffer(maxNumImpulseResponseSamples);
		}
	}

	public inline function getMaxNumImpulses(): Int {
		return impulseBuffer.length;
	}

	public inline function getMaxNumImpulseResponseSamples(): Int {
		return delayBufs[0].length;
	}

	function process(buffer: AudioBuffer) {
		assert(Error, buffer.numChannels == NUM_CHANNELS);

		for (c in 0...buffer.numChannels) {
			final channelView = buffer.getChannelView(c);
			final delayBuf = delayBufs[c];

			for (i in 0...buffer.channelLength) {
				delayBuf.set(channelView[i]);

				var convolutionSum: FastFloat = 0.0;
				for (impulseIndex in 0...impulseBuffer.length) {

					// Move read pointer to impulse position, probably not the
					// most cache efficient operation but it looks pretty unavoidable
					delayBuf.setDelay(impulseBuffer.getImpulsePos(impulseIndex));

					convolutionSum += delayBuf.get() * impulseBuffer.getImpulseMagnitude(impulseIndex);
				}

				// TODO: impulse response must be longer than buffer.channelLength!

				channelView[i] = convolutionSum;
				delayBuf.increment();
			}
		}
	}
}

/**
	A cache efficient buffer to store `(position: Int, magnitude: FastFloat)`
	pairs that represent impulses of varying magnitudes within a sparse impulse
	response. The buffer is **NOT** guaranteed to be zero-initialized.
**/
abstract SparseImpulseBuffer(ByteArray) {

	public var length(get, never): Int;

	public inline function new(numImpulses: Int) {
		this = ByteArray.make(numImpulses * 8);
	}

	public inline function get_length(): Int {
		return this.byteLength >> 3;
	}

	public inline function getImpulsePos(index: Int): Int {
		return this.getUint32(index * 8);
	}

	public inline function setImpulsePos(index: Int, position: Int) {
		this.setUint32(index * 8, position);
	}

	public inline function getImpulseMagnitude(index: Int): FastFloat {
		return this.getFloat32(index * 8 + 4);
	}

	public inline function setImpulseMagnitude(index: Int, magnitude: FastFloat) {
		this.setFloat32(index * 8 + 4, magnitude);
	}
}
