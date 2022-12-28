package aura.types;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.Float32Array;

import aura.utils.MathUtils;

class AudioBuffer {
	public final numChannels: Int;
	public final channelLength: Int;

	public final rawData: Float32Array;
	final channelViews: Vector<AudioBufferChannelView>;

	public inline function new(numChannels: Int, channelLength: Int) {
		this.numChannels = numChannels;
		this.channelLength = channelLength;
		this.rawData = new Float32Array(numChannels * channelLength);

		channelViews = new Vector(numChannels);
		for (c in 0...numChannels) {
			channelViews[c] = this.rawData.subarray(channelLength * c, channelLength * (c + 1));
		}
	}

	public inline function getChannelView(channelIndex: Int): AudioBufferChannelView {
		return channelViews[channelIndex];
	}

	public inline function interleaveToFloat32Array(target: Float32Array, sourceOffset: Int = 0, targetOffset: Int = 0, channelLength: Int = 1) {
		assert(Error, target.length - targetOffset >= numChannels * (channelLength - sourceOffset));

		for (i in 0...minI(this.channelLength, channelLength)) {
			for (c in 0...numChannels) {
				target[targetOffset + i * numChannels + c] = getChannelView(c)[sourceOffset + i];
			}
		}
	}

	public inline function deinterleaveFromFloat32Array(source: Float32Array, numChannels: Int = 1) {
		assert(Error, source.length >= numChannels * channelLength);

		for (i in 0...minI(this.channelLength, channelLength)) {
			for (c in 0...numChannels) {
				getChannelView(c)[i] = source[i * numChannels + c];
			}
		}
	}

	public inline function clear() {
		for (i in 0...rawData.length) {
			rawData[i] = 0;
		}
	}
}

abstract AudioBufferChannelView(Float32Array) from Float32Array {
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
