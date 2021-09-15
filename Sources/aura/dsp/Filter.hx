package aura.dsp;

import aura.utils.BufferUtils.createEmptyVecF;
import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.utils.FrequencyUtils;
import aura.utils.MathUtils;

using aura.utils.StepIterator;

/**
	A simple IIR (infinite impulse response) lowpass/bandpass/highpass filter
	with a slope of 12 dB/octave.
**/
class Filter implements DSP {
	/**
		Whether the filter should be a low-/band- or highpass filter.
	**/
	public var filterMode: FilterMode;

	var inUse = false;

	final buf: Vector<Vector<Float>>;
	var stepSize: Int = 1;
	var off: Bool = false;
	var cutoff: Vector<Float>;

	public inline function new(filterMode: FilterMode) {
		this.filterMode = filterMode;

		this.buf = new Vector(2); // Two channels
		buf[0] = createEmptyVecF(2);  // Two buffers per channel
		buf[1] = createEmptyVecF(2);

		this.cutoff = createEmptyVecF(2);
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		if (off) { return; }

		final start = (stepSize == 2 && cutoff[0] == 1.0) ? 1 : 0;
		for (i in (start...bufferLength).step(stepSize)) {
			// Channel index, buffer is interleaved
			final c = i % 2;

			// http://www.martin-finke.de/blog/articles/audio-plugins-013-filter/
			buf[c][0] += cutoff[c] * (buffer[i] - buf[c][0]);
			buf[c][1] += cutoff[c] * (buf[c][0] - buf[c][1]);

			// TODO: Move the switch out of the loop, even if that means duplicate code?
			buffer[i] = switch (filterMode) {
				case LowPass: buf[c][1];
				case HighPass: buffer[i] - buf[c][0];
				case BandPass: buf[c][0] - buf[c][1];
			}
		}
	}

	/**
		Set the cutoff frequency for this filter. `channels` state for which
		channels to set the cutoff value.
	**/
	public inline function setCutoffFreq(cutoffFreq: Hertz, channels: Channels = Both) {
		final maxFreq = sampleRateToMaxFreq(Aura.sampleRate);
		final c = frequencyToFactor(clampI(cutoffFreq, 0, maxFreq), maxFreq);
		if (Channels.toLeft(channels)) { cutoff[0] = c; }
		if (Channels.toRight(channels)) { cutoff[1] = c; }

		// Optimize process() callback if one or both channels are not affected
		stepSize = (cutoff[0] == 1.0 || cutoff[1] == 1.0) ? 2 : 1;
		off = cutoff[0] == 1.0 && cutoff[1] == 1.0;
	}

	/**
		Get the cutoff frequency of this filter. `channels` state from which
		channels to get the cutoff value, if it's `Both`, the left channel's
		cutoff frequency is returned.
	**/
	public inline function getCutoffFreq(channels: Channels = Both): Hertz {
		final c = Channels.toLeft(channels) ? cutoff[0] : cutoff[1];
		return factorToFrequency(c, sampleRateToMaxFreq(Aura.sampleRate));
	}
}

enum abstract FilterMode(Int) {
	var LowPass;
	var BandPass;
	var HighPass;
}

enum abstract Channels(Int) {
	var Left;
	var Right;
	var Both;

	public static inline function toLeft(channels: Channels): Bool {
		return channels != Right;
	}

	public static inline function toRight(channels: Channels): Bool {
		return channels != Left;
	}
}
