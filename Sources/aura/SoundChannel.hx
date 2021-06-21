package aura;

import aura.BufferUtils.clearBuffer;
import kha.arrays.Float32Array;

import aura.MathUtils;

class SoundChannel extends AudioChannel {
	public static inline var NUM_CHANNELS = 2;

	/**
		Current playback position in seconds.
	**/
	var position: Int = 0;
	var looping: Bool = false;
	var finished: Bool = false;

	var data: Float32Array = null;

	public function new(looping: Bool) {
		this.looping = looping;
	}

	public function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void {
		if (paused || finished) {
			clearBuffer(requestedSamples, requestedLength);
			return;
		}

		var requestedSamplesIndex = 0;
		while (requestedSamplesIndex < requestedLength) {
			for (i in 0...minI(data.length - position, requestedLength - requestedSamplesIndex)) {
				requestedSamples[requestedSamplesIndex++] = data[position++];
			}

			if (position >= data.length) {
				position = 0;
				if (!looping) {
					finished = true;
					break;
				}
			}
		}

		while (requestedSamplesIndex < requestedLength) {
			requestedSamples[requestedSamplesIndex++] = 0;
		}
	}

	public function play(): Void {
		paused = false;
		finished = false;
		// kha.audio1.Audio._playAgain(this);
	}

	public function pause(): Void {
		paused = true;
	}

	public function stop(): Void {
		position = 0;
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
	public inline function getPosition(): Float {
		return position / kha.audio2.Audio.samplesPerSecond / NUM_CHANNELS;
	}

	/**
		Set the channel's current playback position in seconds.
	**/
	public inline function setPosition(value: Float) {
		position = Math.round(value * kha.audio2.Audio.samplesPerSecond * NUM_CHANNELS);
		position = maxI(minI(position, data.length), 0);
	}
}
