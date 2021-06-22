// =============================================================================
// See https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/ResamplingAudioChannel.hx
// =============================================================================

package aura.channels;

import kha.arrays.Float32Array;
import kha.audio2.ResamplingAudioChannel as KhaResamplingAudioChanneL;

import aura.utils.MathUtils;

class ResamplingAudioChannel extends SoundChannel {
	public var sampleRate: Hertz;
	public var pitch: Float = 1.0;
	public var floatPosition: Float = 0.0;

	var mixerChannel: MixerChannel;

	public function new(looping: Bool, sampleRate: Hertz, mixerChannel: MixerChannel) {
		super(looping);
		this.sampleRate = sampleRate;
		this.mixerChannel = mixerChannel;
	};

	override public function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void {
		if (paused || finished) {
			for (i in 0...requestedLength) {
				requestedSamples[i] = 0;
			}
			return;
		}

		var requestedSamplesIndex = 0;
		while (requestedSamplesIndex < requestedLength) {
			for (i in 0...minI(sampleLength(sampleRate) - playbackPosition, requestedLength - requestedSamplesIndex)) {
				// Make sure that we store the actual float position
				floatPosition += pitch;
				playbackPosition = Std.int(floatPosition);

				var sampledVal: Float = sampleFloatPos(floatPosition, i % 2 == 0, sampleRate);

				var b = (i % 2 == 0) ? ~balance : balance;
				// https://sites.uci.edu/computermusic/2013/03/29/constant-power-panning-using-square-root-of-intensity/
				sampledVal *= Math.sqrt(b); // 3dB increase in center position, TODO: make configurable (0, 3, 6 dB)?
				// sampledVal *= minF(1.0, b * 2);

				requestedSamples[requestedSamplesIndex++] = sampledVal;
			}

			if (floatPosition >= sampleLength(sampleRate)) {
				playbackPosition = 0;
				floatPosition = floatPosition % 1; // Keep fraction
				if (!looping) {
					finished = true;
					break;
				}
			}
		}

		while (requestedSamplesIndex < requestedLength) {
			requestedSamples[requestedSamplesIndex++] = 0;
		}

		// TODO: Do not call this here, instead let the mixer channel mix
		// all of its sounds together and then apply inserts

		// For this, set https://github.com/Kode/Kha/blob/f7b6f21b60f1c47402e6fafd519a3d7418d1bf8a/Sources/kha/audio2/Audio1.hx#L35
		// to MasterChannel.mix instead and re-use the same/adapted mix function
		// mixerChannel.processInserts(requestedSamples, requestedLength);
	}

	inline function sampleFloatPos(position: Float, even: Bool, sampleRate: Hertz): Float {
		// Like super.sample(), just with position: Float for correct
		// interpolation of float positions for pitch shifting

		// Also replaced 'even' to correct the stereo output (buffer is interleaved)
		// var even = position % 2 == 0;

		// TODO: Locate clicks (could be an issue with the sound file itself)

		var factor = this.sampleRate / sampleRate;

		position = Std.int(position / 2);
		var pos = factor * position;
		var pos1 = Math.floor(pos);
		var pos2 = Math.floor(pos + 1);
		pos1 *= 2;
		pos2 *= 2;

		var minimum: Int;
		var maximum: Int;

		if (even) {
			minimum = 0;
			maximum = data.length - 1;
			maximum = maximum % 2 == 0 ? maximum : maximum - 1;
		}
		else {
			pos1 += 1;
			pos2 += 1;

			minimum = 1;
			maximum = data.length - 1;
			maximum = maximum % 2 != 0 ? maximum : maximum - 1;
		}

		var a = (pos1 < minimum || pos1 > maximum) ? 0 : data[pos1];
		var b = (pos2 < minimum || pos2 > maximum) ? 0 : data[pos2];
		a = (pos1 > maximum) ? data[maximum] : a;
		b = (pos2 > maximum) ? data[maximum] : b;
		return lerp(a, b, pos - Math.floor(pos));
	}

	inline function sampleLength(sampleRate: Int): Int {
		var value = Math.ceil(data.length * (sampleRate / this.sampleRate));
		return value % 2 == 0 ? value : value + 1;
	}

	override public function stop() {
		super.stop();
		floatPosition = 0.0;
	}

	override public function pause() {
		super.pause();
		floatPosition = playbackPosition;
	}
}
