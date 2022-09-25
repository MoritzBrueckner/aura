package aura.channels.generators;

import haxe.ds.Vector;

import aura.types.AudioBuffer;
import aura.utils.BufferUtils;

/**
	Signal with a frequency spectrum such that the power spectral density
	(energy or power per Hz) is inversely proportional to the frequency of the
	signal. Each octave (halving/doubling in frequency) carries an equal amount
	of noise power.
**/
class PinkNoise extends BaseGenerator {

	final b0: Vector<Float>;
	final b1: Vector<Float>;
	final b2: Vector<Float>;
	final b3: Vector<Float>;
	final b4: Vector<Float>;
	final b5: Vector<Float>;
	final b6: Vector<Float>;

	inline function new() {
		b0 = createEmptyVecF(2);
		b1 = createEmptyVecF(2);
		b2 = createEmptyVecF(2);
		b3 = createEmptyVecF(2);
		b4 = createEmptyVecF(2);
		b5 = createEmptyVecF(2);
		b6 = createEmptyVecF(2);
	}

	/**
		Creates a new PinkNoise channel and returns a handle to it.
	**/
	public static function create(): Handle {
		return new Handle(new PinkNoise());
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {
		for (c in 0...requestedSamples.numChannels) {
			final channelView = requestedSamples.getChannelView(c);

			for (i in 0...requestedSamples.channelLength) {
				final white = Math.random() * 2 - 1;

				// Paul Kellet's refined method from
				// https://www.firstpr.com.au/dsp/pink-noise/
				b0[c] = 0.99886 * b0[c] + white * 0.0555179;
				b1[c] = 0.99332 * b1[c] + white * 0.0750759;
				b2[c] = 0.96900 * b2[c] + white * 0.1538520;
				b3[c] = 0.86650 * b3[c] + white * 0.3104856;
				b4[c] = 0.55000 * b4[c] + white * 0.5329522;
				b5[c] = -0.7616 * b5[c] - white * 0.0168980;
				channelView[i] = b0[c] + b1[c] + b2[c] + b3[c] + b4[c] + b5[c] + b6[c] + white * 0.5362;
				channelView[i] *= 0.11;
				b6[c] = white * 0.115926;
			}
		}

		processInserts(requestedSamples);
	}
}
