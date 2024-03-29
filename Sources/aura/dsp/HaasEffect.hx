package aura.dsp;

import aura.types.AudioBuffer;
import aura.utils.CircularBuffer;
import aura.utils.FrequencyUtils;

/**
	The [Haas effect](https://en.wikipedia.org/wiki/Precedence_effect) is a
	psychoacoustical effect that uses a delay of one stereo channel of ca.
	3 - 50 milliseconds to create the perception of 3D sound.

	Using a negative value for `delay` moves the sound to the left of the
	listener by delaying the right channel. Using a positive value delays the
	left channel and moves the sound to the right. If `delay` is `0`, this
	effect does nothing.
**/
class HaasEffect extends DSP {
	var delayChannelIdx: Int;

	var diffSamples: Int;
	var delayBuff: CircularBuffer;

	public function new(delay: Millisecond) {
		this.diffSamples = 0;
		this.setDelay(delay);
	}

	public function process(buffer: AudioBuffer) {
		if (diffSamples == 0) return;

		for (c in 0...buffer.numChannels) {
			if (c != delayChannelIdx) { continue; }

			final channelView = buffer.getChannelView(c);
			for (i in 0...buffer.channelLength) {
				delayBuff.set(channelView[i]);
				channelView[i] = delayBuff.get();
				delayBuff.increment();
			}
		}
	}

	public function setDelay(delay: Millisecond) {
		final prev = diffSamples;
		this.diffSamples = msToSamples(Aura.sampleRate, delay);
		if (prev != diffSamples) {
			this.delayChannelIdx = (diffSamples > 0) ? 0 : 1;
			this.delayBuff = new CircularBuffer((diffSamples < 0) ? -diffSamples : diffSamples);
		}
	}

	public inline function getDelay(): Millisecond {
		return samplesToMs(Aura.sampleRate, diffSamples);
	}
}
