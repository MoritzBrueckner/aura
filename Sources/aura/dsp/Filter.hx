package aura.dsp;

import aura.utils.BufferUtils.createEmptyVecF;
import haxe.ds.Vector;

import aura.Types;
import aura.types.AudioBuffer;
import aura.utils.FrequencyUtils;
import aura.utils.MathUtils;

using aura.utils.StepIterator;

/**
	A simple IIR (infinite impulse response) lowpass/bandpass/highpass filter
	with a slope of 12 dB/octave.
**/
class Filter extends DSP {
	/**
		Whether the filter should be a low-/band- or highpass filter.
	**/
	public var filterMode: FilterMode;

	final buf: Vector<Vector<Float>>;
	final cutoff: Vector<Float>;

	public function new(filterMode: FilterMode) {
		this.filterMode = filterMode;

		this.buf = new Vector(2); // Two channels
		buf[0] = createEmptyVecF(2);  // Two buffers per channel
		buf[1] = createEmptyVecF(2);

		this.cutoff = new Vector(2);
		cutoff[0] = cutoff[1] = 1.0;
	}

	public function process(buffer: AudioBuffer, bufferLength: Int) {
		for (c in 0...buffer.numChannels) {
			if (cutoff[c] == 1.0) { continue; }

			final channelView = buffer.getChannelView(c);

			for (i in 0...buffer.channelLength) {
				// http://www.martin-finke.de/blog/articles/audio-plugins-013-filter/
				buf[c][0] += cutoff[c] * (channelView[i] - buf[c][0]);
				buf[c][1] += cutoff[c] * (buf[c][0] - buf[c][1]);

				// TODO: Move the switch out of the loop, even if that means duplicate code?
				channelView[i] = switch (filterMode) {
					case LowPass: buf[c][1];
					case HighPass: channelView[i] - buf[c][0];
					case BandPass: buf[c][0] - buf[c][1];
				}
			}
		}
	}

	/**
		Set the cutoff frequency for this filter. `channels` state for which
		channels to set the cutoff value.
	**/
	public inline function setCutoffFreq(cutoffFreq: Hertz, channels: Channels = All) {
		final maxFreq = sampleRateToMaxFreq(Aura.sampleRate);
		final c = frequencyToFactor(clampI(cutoffFreq, 0, maxFreq), maxFreq);
		if (channels.matches(Channels.Left)) { cutoff[0] = c; }
		if (channels.matches(Channels.Right)) { cutoff[1] = c; }
	}

	/**
		Get the cutoff frequency of this filter. `channels` state from which
		channels to get the cutoff value, if it's `Both`, the left channel's
		cutoff frequency is returned.
	**/
	public inline function getCutoffFreq(channels: Channels = All): Hertz {
		final c = channels.matches(Channels.Left) ? cutoff[0] : cutoff[1];
		return factorToFrequency(c, sampleRateToMaxFreq(Aura.sampleRate));
	}
}

enum abstract FilterMode(Int) {
	var LowPass;
	var BandPass;
	var HighPass;
}
