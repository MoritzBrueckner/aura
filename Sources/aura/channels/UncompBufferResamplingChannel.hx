// =============================================================================
// Roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/ResamplingAudioChannel.hx
// =============================================================================

package aura.channels;

import kha.arrays.Float32Array;

import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.MathUtils;
import aura.utils.Interpolator.LinearInterpolator;
import aura.utils.Profiler;
import aura.utils.Resampler;

class UncompBufferResamplingChannel extends UncompBufferChannel {
	public var sampleRate: Hertz;
	public var floatPosition: Float = 0.0;

	final pPitch = new LinearInterpolator(1.0);

	public function new(data: Float32Array, looping: Bool, sampleRate: Hertz) {
		super(data, looping);
		this.sampleRate = sampleRate;
	};

	override function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz): Void {
		Profiler.event();

		assert(Critical, requestedSamples.numChannels == playbackData.numChannels);

		final stepDopplerRatio = pDopplerRatio.getLerpStepSize(requestedSamples.channelLength);
		final stepDstAttenuation = pDstAttenuation.getLerpStepSize(requestedSamples.channelLength);
		final stepPitch = pPitch.getLerpStepSize(requestedSamples.channelLength);
		final stepVol = pVolume.getLerpStepSize(requestedSamples.channelLength);

		final resampleLength = Resampler.getResampleLength(playbackData.channelLength, this.sampleRate, sampleRate);

		var samplesWritten = 0;
		var reachedEndOfData = false;
		// As long as there are more samples requested and there is data left
		while (samplesWritten < requestedSamples.channelLength && !reachedEndOfData) {
			final initialFloatPosition = floatPosition;

			// Check how many samples we can actually write
			final samplesToWrite = minI(resampleLength - playbackPosition, requestedSamples.channelLength - samplesWritten);

			for (c in 0...requestedSamples.numChannels) {
				final outChannelView = requestedSamples.getChannelView(c);

				// Reset interpolators for channel
				pDopplerRatio.currentValue = pDopplerRatio.lastValue;
				pDstAttenuation.currentValue = pDstAttenuation.lastValue;
				pPitch.currentValue = pPitch.lastValue;
				pVolume.currentValue = pVolume.lastValue;

				floatPosition = initialFloatPosition;

				for (i in 0...samplesToWrite) {
					var sampledVal: Float = Resampler.sampleAtTargetPositionLerp(playbackData.getChannelView(c), floatPosition, this.sampleRate, sampleRate);

					outChannelView[samplesWritten + i] = sampledVal * pVolume.currentValue * pDstAttenuation.currentValue;

					floatPosition += pPitch.currentValue * pDopplerRatio.currentValue;

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
							if (c == 0) {
								optionallyApplySourceEffects();
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

		pDopplerRatio.updateLast();
		pDstAttenuation.updateLast();
		pPitch.updateLast();
		pVolume.updateLast();

		processInserts(requestedSamples);
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

	override function parseMessage(message: Message) {
		switch (message.id) {
			case ChannelMessageID.PPitch: pPitch.targetValue = cast message.data;

			default:
				super.parseMessage(message);
		}
	}
}
