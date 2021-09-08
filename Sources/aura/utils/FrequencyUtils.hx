package aura.utils;

import aura.utils.Assert.*;

@:pure inline function frequencyToFactor(freq: Hertz, maxFreq: Hertz): Float {
	assert(Debug, freq <= maxFreq);

	return freq / maxFreq;
}

@:pure inline function factorToFrequency(factor: Float, maxFreq: Hertz): Hertz {
	assert(Debug, 0.0 <= factor && factor <= 1.0);

	return Std.int(factor * maxFreq);
}

@:pure inline function sampleRateToMaxFreq(sampleRate: Hertz): Hertz {
	return Std.int(sampleRate / 2.0);
}

@:pure inline function msToSamples(sampleRate: Hertz, milliseconds: Millisecond): Int {
	return Std.int((milliseconds / 1000.0) * sampleRate);
}

@:pure inline function samplesToMs(sampleRate: Hertz, samples: Int): Millisecond {
	return (samples / sampleRate) * 1000;
}
