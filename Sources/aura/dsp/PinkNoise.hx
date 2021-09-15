package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.utils.BufferUtils;

/**
	Signal with a frequency spectrum such that the power spectral density
	(energy or power per Hz) is inversely proportional to the frequency of the
	signal. Each octave (halving/doubling in frequency) carries an equal amount
	of noise power.
**/
class PinkNoise implements DSP {

	var inUse = false;

	final b0: Vector<Float>;
	final b1: Vector<Float>;
	final b2: Vector<Float>;
	final b3: Vector<Float>;
	final b4: Vector<Float>;
	final b5: Vector<Float>;
	final b6: Vector<Float>;

	public inline function new() {
		b0 = createEmptyVecF(2);
		b1 = createEmptyVecF(2);
		b2 = createEmptyVecF(2);
		b3 = createEmptyVecF(2);
		b4 = createEmptyVecF(2);
		b5 = createEmptyVecF(2);
		b6 = createEmptyVecF(2);
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		var c = 0;
		for (i in 0...bufferLength) {
			final white = Math.random() * 2 - 1;
			b0[c] = 0.99886 * b0[c] + white * 0.0555179;
			b1[c] = 0.99332 * b1[c] + white * 0.0750759;
			b2[c] = 0.96900 * b2[c] + white * 0.1538520;
			b3[c] = 0.86650 * b3[c] + white * 0.3104856;
			b4[c] = 0.55000 * b4[c] + white * 0.5329522;
			b5[c] = -0.7616 * b5[c] - white * 0.0168980;
			buffer[i] = b0[c] + b1[c] + b2[c] + b3[c] + b4[c] + b5[c] + b6[c] + white * 0.5362;
			buffer[i] *= 0.11;
			b6[c] = white * 0.115926;
			c = 1 - c;
		}
	}
}
