package aura.channels.generators;

import aura.types.AudioBuffer;

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

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {
		for (i in 0...requestedSamples.rawData.length) {
			requestedSamples.rawData[i] = Math.random() * 2 - 1;
		}

		processInserts(requestedSamples);
	}
}
