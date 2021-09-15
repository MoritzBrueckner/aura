package aura.dsp;

import kha.arrays.Float32Array;

/**
	Signal noise produced by Brownian motion.
**/
class BrownNoise implements DSP {

	var inUse = false;

	public inline function new() {}

	public function process(buffer: Float32Array, bufferLength: Int) {
		var last = 0.0;
		for (i in 0...bufferLength) {
			final white = Math.random() * 2 - 1;
			buffer[i] = (last + (0.02 * white)) / 1.02;
			last = buffer[i];
			buffer[i] *= 3.5;
		}
	}
}
