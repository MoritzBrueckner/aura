package aura.channels;

import kha.arrays.Float32Array;

import aura.utils.MathUtils;
import aura.threading.Message;

class AudioChannel extends BaseChannel {
	public static inline var NUM_CHANNELS = 2;

	/**
		Current playback position in seconds.
	**/
	var playbackPosition: Int = 0;
	var looping: Bool = false;

	var data: Float32Array = null;

	public function new(looping: Bool) {
		this.looping = looping;
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void {
		final lerpTime = Std.int(requestedLength / 2); // Stereo, 2 samples per frame
		final stepBalance = pBalance.getLerpStepSize(lerpTime);
		final stepDopplerRatio = pDopplerRatio.getLerpStepSize(lerpTime);
		final stepDstAttenuation = pDstAttenuation.getLerpStepSize(lerpTime);
		final stepVol = pVolume.getLerpStepSize(lerpTime);

		var requestedSamplesIndex = 0;
		while (requestedSamplesIndex < requestedLength) {
			var isLeft = true;

			for (_ in 0...minI(data.length - playbackPosition, requestedLength - requestedSamplesIndex)) {
				requestedSamples[requestedSamplesIndex++] = data[playbackPosition++] * pVolume.currentValue * pDstAttenuation.currentValue;

				if (!isLeft) {
					pBalance.currentValue += stepBalance;
					pDopplerRatio.currentValue += stepDopplerRatio;
					pDstAttenuation.currentValue += stepDstAttenuation;
					pVolume.currentValue += stepVol;
				}

				isLeft = !isLeft;
			}

			if (playbackPosition >= data.length) {
				playbackPosition = 0;
				if (!looping) {
					finished = true;
					break;
				}
			}
		}

		while (requestedSamplesIndex < requestedLength) {
			requestedSamples[requestedSamplesIndex++] = 0;
		}

		processInserts(requestedSamples, requestedLength);

		pBalance.updateLast();
		pDopplerRatio.updateLast();
		pDstAttenuation.updateLast();
		pVolume.updateLast();
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
		return data.length / kha.audio2.Audio.samplesPerSecond / NUM_CHANNELS;
	}

	/**
		Return the channel's current playback position in seconds.
	**/
	public inline function getPlaybackPosition(): Float {
		return playbackPosition / kha.audio2.Audio.samplesPerSecond / NUM_CHANNELS;
	}

	/**
		Set the channel's current playback position in seconds.
	**/
	public inline function setPlaybackPosition(value: Float) {
		playbackPosition = Math.round(value * kha.audio2.Audio.samplesPerSecond * NUM_CHANNELS);
		playbackPosition = maxI(minI(playbackPosition, data.length), 0);
	}
}
