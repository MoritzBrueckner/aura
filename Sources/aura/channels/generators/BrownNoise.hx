package aura.channels.generators;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.utils.BufferUtils;

/**
	Signal noise produced by Brownian motion.
**/
class BrownNoise extends BaseGenerator {
	final last: Vector<Float>;

	inline function new() {
		last = createEmptyVecF(2);
	}

	/**
		Creates a new BrownNoise channel and returns a handle to it.
	**/
	public static function create(): Handle {
		return new Handle(new BrownNoise());
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {
		var c = 0;
		for (i in 0...requestedLength) {
			final white = Math.random() * 2 - 1;
			requestedSamples[i] = (last[c] + (0.02 * white)) / 1.02;
			last[c] = requestedSamples[i];
			requestedSamples[i] *= 3.5;
			c = 1 - c;
		}
	}
}
