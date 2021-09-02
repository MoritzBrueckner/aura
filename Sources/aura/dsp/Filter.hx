package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.utils.FrequencyUtils;

/**
	A simple IIR (infinite impulse response) lowpass/bandpass/highpass filter
	with a slope of 12 dB/octave.
**/
class Filter implements DSP {
	public var mode: FilterMode;

	final buf: Vector<Vector<Float>>;
	var cutoff = 1.0;

	public inline function new(mode: FilterMode) {
		this.mode = mode;

		this.buf = new Vector(2); // Two channels
		buf[0] = new Vector(2);  // Two buffers per channel
		buf[1] = new Vector(2);
		buf[0][0] = 0.0;
		buf[0][1] = 0.0;
		buf[1][0] = 0.0;
		buf[1][1] = 0.0;
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		for (i in 0...bufferLength) {
			// Channel index, buffer is interleaved
			final c = i % 2;

			// http://www.martin-finke.de/blog/articles/audio-plugins-013-filter/
			buf[c][0] += cutoff * (buffer[i] - buf[c][0]);
			buf[c][1] += cutoff * (buf[c][0] - buf[c][1]);

			// TODO: Move the switch out of the loop, even if that means duplicate code?
			buffer[i] = switch (mode) {
				case LowPass: buf[c][1];
				case HighPass: buffer[i] - buf[c][0];
				case BandPass: buf[c][0] - buf[c][1];
			}
		}
	}

	public inline function setCutoffFreq(cutoffFreq: Hertz) {
		cutoff = frequencyToFactor(cutoffFreq, sampleRateToMaxFreq(Aura.sampleRate));
	}

	public inline function getCutoffFreq(): Hertz {
		return factorToFrequency(cutoff, sampleRateToMaxFreq(Aura.sampleRate));
	}
}

enum abstract FilterMode(Int) {
	var LowPass;
	var BandPass;
	var HighPass;
}
