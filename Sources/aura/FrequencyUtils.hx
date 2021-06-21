package aura;

import aura.Assert.assert;
import aura.Assert.*;

@:pure inline function frequencyToFactor(freq: Hertz, maxFreq: Hertz): Float {
	// assert(freq < maxFreq, Debug);
	return freq / maxFreq;
}

@:pure inline function factorToFrequency(factor: Float, maxFreq: Hertz): Hertz {
	// assert(0.0 < fac && fac < 1.0, Debug);
	return Std.int(factor * maxFreq);
}

@:pure inline function sampleRateToMaxFreq(sampleRate: Hertz): Hertz {
	return Std.int(sampleRate / 2.0);
}
