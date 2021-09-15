package aura.dsp;

import kha.arrays.Float32Array;

/**
 * 	Signal with a frequency spectrum such that the power spectral density (energy or power per Hz) is inversely proportional to the frequency of the signal.
	Each octave (halving/doubling in frequency) carries an equal amount of noise power.
 */
class PinkNoise implements DSP {

    var inUse = false;

    public inline function new() {
    }

    public function process(buffer: Float32Array, bufferLength: Int) {
        var b0, b1, b2, b3, b4, b5, b6;
		b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0;
		for( i in 0...bufferLength ) {
			var white = Math.random() * 2 - 1;
			b0 = 0.99886 * b0 + white * 0.0555179;
			b1 = 0.99332 * b1 + white * 0.0750759;
			b2 = 0.96900 * b2 + white * 0.1538520;
			b3 = 0.86650 * b3 + white * 0.3104856;
			b4 = 0.55000 * b4 + white * 0.5329522;
			b5 = -0.7616 * b5 - white * 0.0168980;
			buffer[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
			buffer[i] *= 0.11;
			b6 = white * 0.115926;
		}
    }

}
