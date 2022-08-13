// =============================================================================
// Roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/ResamplingAudioChannel.hx
// =============================================================================

package aura.channels;

import kha.arrays.Float32Array;

import aura.types.AudioBuffer;
import aura.utils.MathUtils;
import aura.utils.Interpolator.LinearInterpolator;
import aura.threading.Message;

class ResamplingAudioChannel extends AudioChannel {
	public var sampleRate: Hertz;
	public var floatPosition: Float = 0.0;

	final pPitch = new LinearInterpolator(1.0);

	public function new(data: Float32Array, looping: Bool, sampleRate: Hertz) {
		super(data, looping);
		this.sampleRate = sampleRate;
	};

	override function nextSamples(requestedSamples: AudioBuffer, requestedLength: Int, sampleRate: Hertz): Void {
		assert(Critical, requestedSamples.numChannels == data.numChannels);

		final stepBalance = pBalance.getLerpStepSize(requestedSamples.channelLength);
		final stepDopplerRatio = pDopplerRatio.getLerpStepSize(requestedSamples.channelLength);
		final stepDstAttenuation = pDstAttenuation.getLerpStepSize(requestedSamples.channelLength);
		final stepPitch = pPitch.getLerpStepSize(requestedSamples.channelLength);
		final stepVol = pVolume.getLerpStepSize(requestedSamples.channelLength);

		final resampleLength = getResampleLength(sampleRate);

		var samplesWritten = 0;
		var reachedEndOfData = false;
		// As long as there are more samples requested and there is data left
		while (samplesWritten < requestedLength && !reachedEndOfData) {
			final initialFloatPosition = floatPosition;

			// Check how many samples we can actually write
			final samplesToWrite = minI(resampleLength - playbackPosition, requestedSamples.channelLength - samplesWritten);

			for (c in 0...requestedSamples.numChannels) {
				final outChannelView = requestedSamples.getChannelView(c);

				// Reset interpolators for channel
				pBalance.currentValue = pBalance.lastValue;
				pDopplerRatio.currentValue = pDopplerRatio.lastValue;
				pDstAttenuation.currentValue = pDstAttenuation.lastValue;
				pPitch.currentValue = pPitch.lastValue;
				pVolume.currentValue = pVolume.lastValue;

				floatPosition = initialFloatPosition;

				for (i in 0...samplesToWrite) {
					floatPosition += pPitch.currentValue * pDopplerRatio.currentValue;

					var sampledVal: Float = sampleFloatPos(floatPosition, c, sampleRate);

					final balance: Balance = pBalance.currentValue;
					final b = (c == 0) ? ~balance : (
						c == 1 ? balance : 1.0
					);
					// https://sites.uci.edu/computermusic/2013/03/29/constant-power-panning-using-square-root-of-intensity/
					sampledVal *= Math.sqrt(b); // 3dB increase in center position, TODO: make configurable (0, 3, 6 dB)?

					outChannelView[samplesWritten + i] = sampledVal * pVolume.currentValue * pDstAttenuation.currentValue;

					pBalance.currentValue += stepBalance;
					pDopplerRatio.currentValue += stepDopplerRatio;
					pDstAttenuation.currentValue += stepDstAttenuation;
					pPitch.currentValue += stepPitch;
					pVolume.currentValue += stepVol;

					if (floatPosition >= resampleLength) {
						if (looping) {
							while (floatPosition >= resampleLength) {
								playbackPosition -= resampleLength;
								floatPosition -= resampleLength; // Keep fraction
							}
						}
						else {
							stop();
							reachedEndOfData = true;
							break;
						}
					}
					else {
						playbackPosition = Std.int(floatPosition);
					}
				}
			}
			samplesWritten += samplesToWrite;
		}

		// Fill further requested samples with zeroes
		for (c in 0...requestedSamples.numChannels) {
			final channelView = requestedSamples.getChannelView(c);
			for (i in samplesWritten...requestedSamples.channelLength) {
				channelView[i] = 0;
			}
		}

		pBalance.updateLast();
		pDopplerRatio.updateLast();
		pDstAttenuation.updateLast();
		pPitch.updateLast();
		pVolume.updateLast();

		processInserts(requestedSamples, requestedLength);
	}

	inline function sampleFloatPos(position: Float, channel: Int, sampleRate: Hertz): Float {
		// Like super.sample(), just with floating point position

		assert(Critical, position >= 0.0);

		final factor = this.sampleRate / sampleRate;
		final pos = factor * position;

		final channelView = data.getChannelView(channel);

		final maxPos = data.channelLength - 1;
		final pos1 = Math.floor(pos);
		final pos2 = pos1 + 1;

		final value1 = (pos1 > maxPos) ? channelView[maxPos] : channelView[pos1];
		final value2 = (pos2 > maxPos) ? channelView[maxPos] : channelView[pos2];

		return lerp(value1, value2, pos - Math.floor(pos));
	}

	/**
		Calculate how many samples are required for a channel of the current
		data after resampling it to the `targetSampleRate`.
	**/
	inline function getResampleLength(targetSampleRate: Hertz): Int {
		return Math.ceil(data.channelLength * (targetSampleRate / this.sampleRate));
	}

	override public function play(retrigger: Bool) {
		super.play(retrigger);
		if (retrigger) {
			floatPosition = 0.0;
		}
	}

	override public function stop() {
		super.stop();
		floatPosition = 0.0;
	}

	override public function pause() {
		super.pause();
		floatPosition = playbackPosition;
	}

	override function parseMessage(message: ChannelMessage) {
		switch (message.id) {
			case PPitch: pPitch.targetValue = cast message.data;

			default:
				super.parseMessage(message);
		}
	}
}
