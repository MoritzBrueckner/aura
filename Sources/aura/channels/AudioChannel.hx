package aura.channels;

import kha.arrays.Float32Array;

import aura.utils.MathUtils;
import aura.threading.Message;
import aura.types.AudioBuffer;

class AudioChannel extends BaseChannel {
	public static inline var NUM_CHANNELS = 2;

	/** The current playback position in samples. **/
	var playbackPosition: Int = 0;
	var looping: Bool = false;

	var data: AudioBuffer;

	public function new(data: Float32Array, looping: Bool) {
		this.data = new AudioBuffer(2, Std.int(data.length / 2));
		this.data.deinterleaveFromFloat32Array(data, 2);
		this.looping = looping;
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz): Void {
		assert(Critical, requestedSamples.numChannels == data.numChannels);

		final stepDopplerRatio = pDopplerRatio.getLerpStepSize(requestedSamples.channelLength);
		final stepDstAttenuation = pDstAttenuation.getLerpStepSize(requestedSamples.channelLength);
		final stepVol = pVolume.getLerpStepSize(requestedSamples.channelLength);

		var samplesWritten = 0;
		// As long as there are more samples requested
		while (samplesWritten < requestedSamples.channelLength) {

			// Check how many samples we can actually write
			final samplesToWrite = minI(data.channelLength - playbackPosition, requestedSamples.channelLength - samplesWritten);
			for (c in 0...requestedSamples.numChannels) {
				final outChannelView = requestedSamples.getChannelView(c);
				final dataChannelView = data.getChannelView(c);

				// Reset interpolators for channel
				pDopplerRatio.currentValue = pDopplerRatio.lastValue;
				pDstAttenuation.currentValue = pDstAttenuation.lastValue;
				pVolume.currentValue = pVolume.lastValue;

				for (i in 0...samplesToWrite) {
					final value = dataChannelView[playbackPosition + i] * pVolume.currentValue * pDstAttenuation.currentValue;
					outChannelView[samplesWritten + i] = value;

					// TODO: SIMD
					pDopplerRatio.currentValue += stepDopplerRatio;
					pDstAttenuation.currentValue += stepDstAttenuation;
					pVolume.currentValue += stepVol;
				}
			}
			samplesWritten += samplesToWrite;
			playbackPosition += samplesToWrite;

			if (playbackPosition >= data.channelLength) {
				playbackPosition = 0;
				if (!looping) {
					finished = true;
					break;
				}
			}
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
		pVolume.updateLast();

		processInserts(requestedSamples);
	}

	public function play(retrigger: Bool): Void {
		paused = false;
		finished = false;
		if (retrigger) {
			playbackPosition = 0;
		}
	}

	public function pause(): Void {
		paused = true;
	}

	public function stop(): Void {
		playbackPosition = 0;
		finished = true;
	}

	/**
		Returns whether the sound has stopped playing.
	**/
	public inline function isFinished(): Bool {
		return finished;
	}

	/**
		Return the sound's length in seconds.
	**/
	public inline function getLength(): Float {
		return data.channelLength / kha.audio2.Audio.samplesPerSecond;
	}

	/**
		Return the channel's current playback position in seconds.
	**/
	public inline function getPlaybackPosition(): Float {
		return playbackPosition / kha.audio2.Audio.samplesPerSecond;
	}

	/**
		Set the channel's current playback position in seconds.
	**/
	public inline function setPlaybackPosition(value: Float) {
		playbackPosition = Math.round(value * kha.audio2.Audio.samplesPerSecond);
		playbackPosition = clampI(playbackPosition, 0, data.channelLength);
	}
}
