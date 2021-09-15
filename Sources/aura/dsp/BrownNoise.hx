package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.utils.BufferUtils;

/**
	Signal noise produced by Brownian motion.
**/
class BrownNoise implements DSP {

	var inUse = false;

	final last: Vector<Float>;

	public inline function new() {
		last = createEmptyVecF(2);
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		var c = 0;
		for (i in 0...bufferLength) {
			final white = Math.random() * 2 - 1;
			buffer[i] = (last[c] + (0.02 * white)) / 1.02;
			last[c] = buffer[i];
			buffer[i] *= 3.5;
			c = 1 - c;
		}
	}
}
