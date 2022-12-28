package aura.channels.generators;

import haxe.ds.Vector;

import kha.FastFloat;

import aura.types.AudioBuffer;
import aura.utils.BufferUtils;

/**
	Signal noise produced by Brownian motion.
**/
class BrownNoise extends BaseGenerator {
	final last: Vector<FastFloat>;

	inline function new() {
		last = createEmptyVecF32(2);
	}

	/**
		Creates a new BrownNoise channel and returns a handle to it.
	**/
	public static function create(): Handle {
		return new Handle(new BrownNoise());
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {
		for (c in 0...requestedSamples.numChannels) {
			final channelView = requestedSamples.getChannelView(c);

			for (i in 0...requestedSamples.channelLength) {
				final white = Math.random() * 2 - 1;
				channelView[i] = (last[c] + (0.02 * white)) / 1.02;
				last[c] = channelView[i];
				channelView[i] * 3.5;
			}
		}

		processInserts(requestedSamples);
	}
}
