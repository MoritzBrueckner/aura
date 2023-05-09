package aura.channels;

import kha.arrays.Float32Array;

import aura.channels.BaseChannel.BaseChannelHandle;
import aura.dsp.sourcefx.SourceEffect;
import aura.utils.MathUtils;
import aura.threading.Message;
import aura.types.AudioBuffer;

// TODO make handle thread-safe!

@:access(aura.channels.UncompBufferChannel)
class UncompBufferChannelHandle extends BaseChannelHandle {

	final _sourceEffects: Array<SourceEffect> = []; // main-thread twin of channel.sourceEffects. TODO investigate better solution
	var _playbackDataLength = -1;

	inline function getUncompBufferChannel(): UncompBufferChannel {
		return cast this.channel;
	}

	/**
		Return the sound's length in seconds.
	**/
	public inline function getLength(): Float {
		return getUncompBufferChannel().data.channelLength / Aura.sampleRate;
	}

	/**
		Return the channel's current playback position in seconds.
	**/
	public inline function getPlaybackPosition(): Float {
		return getUncompBufferChannel().playbackPosition / Aura.sampleRate;
	}

	/**
		Set the channel's current playback position in seconds.
	**/
	public inline function setPlaybackPosition(value: Float) {
		final pos = Math.round(value * Aura.sampleRate);
		getUncompBufferChannel().playbackPosition = clampI(pos, 0, getUncompBufferChannel().data.channelLength);
	}

	public function addSourceEffect(sourceEffect: SourceEffect) {
		_sourceEffects.push(sourceEffect);
		final playbackData = updatePlaybackBuffer();

		getUncompBufferChannel().sendMessage({ id: UncompBufferChannelMessageID.AddSourceEffect, data: [sourceEffect, playbackData] });
	}

	public function removeSourceEffect(sourceEffect: SourceEffect) {
		if (_sourceEffects.remove(sourceEffect)) {
			final playbackData = updatePlaybackBuffer();
			getUncompBufferChannel().sendMessage({ id: UncompBufferChannelMessageID.RemoveSourceEffect, data: [sourceEffect, playbackData] });
		}
	}

	@:access(aura.dsp.sourcefx.SourceEffect)
	function updatePlaybackBuffer(): Null<AudioBuffer> {
		final data = getUncompBufferChannel().data;
		var playbackData: Null<AudioBuffer> = null;

		if (_sourceEffects.length == 0) {
			playbackData = data;
		}
		else {
			var requiredChannelLength = data.channelLength;
			var prevChannelLength = data.channelLength;

			for (sourceEffect in _sourceEffects) {
				prevChannelLength = sourceEffect.calculateRequiredChannelLength(prevChannelLength);
				requiredChannelLength = maxI(requiredChannelLength, prevChannelLength);
			}

			if (_playbackDataLength != requiredChannelLength) {
				playbackData = new AudioBuffer(data.numChannels, requiredChannelLength);
				_playbackDataLength = requiredChannelLength;
			}
		}

		// if null -> no buffer to change in channel
		return playbackData;
	}
}

@:allow(aura.channels.UncompBufferChannelHandle)
class UncompBufferChannel extends BaseChannel {
	public static inline var NUM_CHANNELS = 2;

	final sourceEffects: Array<SourceEffect> = [];

	var appliedSourceEffects = false;

	/** The current playback position in samples. **/
	var playbackPosition: Int = 0;
	var looping: Bool = false;

	/**
		The original audio source data for this channel.
	**/
	final data: AudioBuffer;

	/**
		The audio data used for playback. This might be different than `this.data`
		if this channel has `AudioSourceEffect`s assigned to it.
	**/
	var playbackData: AudioBuffer;

	public function new(data: Float32Array, looping: Bool) {
		this.data = this.playbackData = new AudioBuffer(2, Std.int(data.length / 2));
		this.data.deinterleaveFromFloat32Array(data, 2);
		this.looping = looping;
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			case UncompBufferChannelMessageID.AddSourceEffect:
				final sourceEffect: SourceEffect = message.dataAsArrayUnsafe()[0];
				final _playbackData = message.dataAsArrayUnsafe()[1];
				if (_playbackData != null) {
					playbackData = _playbackData;
				}
				addSourceEffect(sourceEffect);

			case UncompBufferChannelMessageID.RemoveSourceEffect:
				final sourceEffect: SourceEffect = message.dataAsArrayUnsafe()[0];
				final _playbackData = message.dataAsArrayUnsafe()[1];
				if (_playbackData != null) {
					playbackData = _playbackData;
				}
				removeSourceEffect(sourceEffect);

			default: super.parseMessage(message);
		}
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz): Void {
		assert(Critical, requestedSamples.numChannels == playbackData.numChannels);

		final stepDopplerRatio = pDopplerRatio.getLerpStepSize(requestedSamples.channelLength);
		final stepDstAttenuation = pDstAttenuation.getLerpStepSize(requestedSamples.channelLength);
		final stepVol = pVolume.getLerpStepSize(requestedSamples.channelLength);

		var samplesWritten = 0;
		// As long as there are more samples requested
		while (samplesWritten < requestedSamples.channelLength) {

			// Check how many samples we can actually write
			final samplesToWrite = minI(playbackData.channelLength - playbackPosition, requestedSamples.channelLength - samplesWritten);
			for (c in 0...requestedSamples.numChannels) {
				final outChannelView = requestedSamples.getChannelView(c);
				final dataChannelView = playbackData.getChannelView(c);

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

			if (playbackPosition >= playbackData.channelLength) {
				playbackPosition = 0;
				if (looping) {
					optionallyApplySourceEffects();
				}
				else {
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

	function play(retrigger: Bool): Void {
		if (finished || retrigger || !appliedSourceEffects) {
			optionallyApplySourceEffects();
		}

		paused = false;
		finished = false;
		if (retrigger) {
			playbackPosition = 0;
		}
	}

	function pause(): Void {
		paused = true;
	}

	function stop(): Void {
		playbackPosition = 0;
		finished = true;
	}

	inline function addSourceEffect(audioSourceEffect: SourceEffect) {
		sourceEffects.push(audioSourceEffect);
		appliedSourceEffects = false;
	}

	inline function removeSourceEffect(audioSourceEffect: SourceEffect) {
		sourceEffects.remove(audioSourceEffect);
		appliedSourceEffects = false;
	}

	/**
		Apply all source effects to `playbackData`, if there are any.
	**/
	@:access(aura.dsp.sourcefx.SourceEffect)
	function optionallyApplySourceEffects() {
		var currentSrcBuffer = data;
		var previousLength = data.channelLength;

		var needsReprocessing = !appliedSourceEffects;

		if (!needsReprocessing) {
			for (sourceEffect in sourceEffects) {
				if (sourceEffect.applyOnReplay.load()) {
					needsReprocessing = true;
					break;
				}
			}
		}

		if (needsReprocessing) {
			for (sourceEffect in sourceEffects) {
				previousLength = sourceEffect.process(currentSrcBuffer, previousLength, playbackData);
				currentSrcBuffer = playbackData;
			}
		}

		appliedSourceEffects = true;
	}
}

private class UncompBufferChannelMessageID extends ChannelMessageID {
	final AddSourceEffect;
	final RemoveSourceEffect;
}
