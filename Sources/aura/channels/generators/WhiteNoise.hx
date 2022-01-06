package aura.channels.generators;

import kha.arrays.Float32Array;

/**
	Random signal with a constant power spectral density.
**/
class WhiteNoise extends BaseGenerator {

	inline function new() {}

	/**
		Creates a new WhiteNoise channel and returns a handle to it.
	**/
	public static function create(): Handle {
		return new Handle(new WhiteNoise());
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {
		for (i in 0...requestedLength) {
			requestedSamples[i] = Math.random() * 2 - 1;
		}

		processInserts(requestedSamples, requestedLength);
	}
}
