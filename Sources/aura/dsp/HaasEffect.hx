package aura.dsp;

import kha.arrays.Float32Array;

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
class HaasEffect implements DSP {
	var delayChannelIdx: Int;

	var diffSamples: Int;
	var delayBuff: CircularBuffer<Float>;

	public inline function new(delay: Millisecond) {
		this.diffSamples = 0;
		this.setDelay(delay);
	}

	public function process(buffer: Float32Array, bufferLength: Int) {
		if (diffSamples == 0) return;

		for (i in 0...bufferLength) {
			if (i % 2 == delayChannelIdx) {
				delayBuff.set(buffer[i]);
				buffer[i] = delayBuff.get();
				delayBuff.increment();
			}
		}
	}

	public function setDelay(delay: Millisecond) {
		var prev = diffSamples;
		this.diffSamples = msToSamples(48000, delay) * 2;
		if (prev != diffSamples) {
			this.delayChannelIdx = (diffSamples > 0) ? 0 : 1;
			this.delayBuff = new CircularBuffer((diffSamples < 0) ? -diffSamples : diffSamples);
		}
	}

	public inline function getDelay(): Millisecond {
		return samplesToMs(48000, Std.int(diffSamples / 2));
	}
}
