package aura.types;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.Float32Array;

/**
	Deinterleaved 32-bit floating point audio buffer.
**/
class AudioBuffer {

	/**
		The amount of audio channels in this buffer.
	**/
	public final numChannels: Int;

	/**
		The amount of samples stored in each channel of this buffer.
	**/
	public final channelLength: Int;

	/**
		The raw samples data of this buffer.

		To access the samples of a specific channel, please use
		`AudioBuffer.getChannelView()`.
	**/
	public final rawData: Float32Array;

	final channelViews: Vector<AudioBufferChannelView>;

	/**
		Create a new `AudioBuffer` object.

		@param numChannels The amount of audio channels in this buffer.
		@param channelLength The amount of samples stored in each channel.
	**/
	public inline function new(numChannels: Int, channelLength: Int) {
		assert(Error, numChannels > 0);
		assert(Error, channelLength > 0);

		this.numChannels = numChannels;
		this.channelLength = channelLength;
		this.rawData = new Float32Array(numChannels * channelLength);

		channelViews = new Vector(numChannels);
		for (c in 0...numChannels) {
			channelViews[c] = this.rawData.subarray(channelLength * c, channelLength * (c + 1));
		}
	}

	/**
		Get access to the samples data in the audio channel specified by `channelIndex`.
	**/
	public inline function getChannelView(channelIndex: Int): AudioBufferChannelView {
		assert(Error, 0 <= channelIndex && channelIndex < this.numChannels);

		return channelViews[channelIndex];
	}

	/**
		Copy and interleave this `AudioBuffer` into the given `target` array.

		@param sourceOffset Per-channel position in this `AudioBuffer` from where to start copying and interleaving samples.
		@param targetOffset Absolute position in the target array at which to start writing samples.
		@param numSamplesToCopy The amount of samples to copy (per channel).
	**/
	public inline function interleaveToFloat32Array(target: Float32Array, sourceOffset: Int, targetOffset: Int, numSamplesToCopy: Int) {
		assert(Error, numSamplesToCopy >= 0);

		assert(Error, sourceOffset >= 0);
		assert(Error, sourceOffset + numSamplesToCopy <= this.channelLength);

		assert(Error, targetOffset >= 0);
		assert(Error, targetOffset + numSamplesToCopy * this.numChannels <= target.length);

		for (i in 0...numSamplesToCopy) {
			for (c in 0...numChannels) {
				target[targetOffset + i * numChannels + c] = getChannelView(c)[sourceOffset + i];
			}
		}
	}

	/**
		Copy and deinterleave the given `source` array into this `AudioBuffer`.

		@param source An interleaved array of audio samples.
		@param numSourceChannels The amount of channels in the `source` array,
			which must be smaller or equal to the amount of channels in this
			`AudioBuffer`. The source channels are copied to the `numSourceChannels`
			first channels in this `AudioBuffer`.
	**/
	public inline function deinterleaveFromFloat32Array(source: Float32Array, numSourceChannels: Int) {
		assert(Error, numSourceChannels >= 0 && numSourceChannels <= this.numChannels);

		assert(Error, source.length >= numSourceChannels * this.channelLength);

		for (i in 0...channelLength) {
			for (c in 0...numSourceChannels) {
				getChannelView(c)[i] = source[i * numSourceChannels + c];
			}
		}
	}

	/**
		Fill each audio channel in this buffer with zeroes.
	**/
	public inline function clear() {
		for (i in 0...rawData.length) {
			rawData[i] = 0;
		}
	}

	/**
		Copy the samples from `other` into this buffer.
		Both buffers must have the same amount of channels
		and the same amount of samples per channel.
	**/
	public inline function copyFromEquallySized(other: AudioBuffer) {
		assert(Error, this.numChannels == other.numChannels);
		assert(Error, this.channelLength == other.channelLength);

		for (i in 0...rawData.length) {
			this.rawData[i] = other.rawData[i];
		}
	}

	/**
		Copy the samples from `other` into this buffer.
		Both buffers must have the same amount of channels, `other` must have
		fewer or equal the amount of samples per channel than this buffer.

		If `other` has fewer samples per channel than this buffer,
		`padWithZeroes` specifies whether the remaining samples in this buffer
		should be padded with zeroes (`padWithZeroes` is `true`) or should be
		remain unmodified (`padWithZeroes` is `false`).
	**/
	public inline function copyFromShorterBuffer(other: AudioBuffer, padWithZeroes: Bool) {
		assert(Error, this.numChannels == other.numChannels);
		assert(Error, this.channelLength >= other.channelLength);

		for (c in 0...this.numChannels) {
			final thisView = this.getChannelView(c);
			final otherView = other.getChannelView(c);

			for (i in 0...other.channelLength) {
				thisView[i] = otherView[i];
			}

			if (padWithZeroes) {
				for (i in other.channelLength...this.channelLength) {
					thisView[i] = 0.0;
				}
			}
		}
	}
}

/**
	An array-like view on the samples data of an `AudioBuffer` channel.
**/
abstract AudioBufferChannelView(Float32Array) from Float32Array to Float32Array {
	public function new(size: Int) {
		this = new Float32Array(size);
	}

	@:arrayAccess
	public function get(index: Int): FastFloat {
		return this.get(index);
	}

	@:arrayAccess
	public function set(index: Int, value: FastFloat): FastFloat {
		return this.set(index, value);
	}
}
