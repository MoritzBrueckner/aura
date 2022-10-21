package aura.channels;

import aura.utils.Pointer;
import kha.arrays.Float32Array;

import aura.threading.BufferCache;
import aura.threading.Message;
import aura.types.AudioBuffer;

/**
	Wrapper around `kha.audio2.StreamChannel` (for now).
**/
class StreamChannel extends BaseChannel {
	final khaChannel: kha.audio2.StreamChannel;
	final p_khaBuffer = new Pointer<Float32Array>(null);

	public function new(khaChannel: kha.audio2.StreamChannel) {
		this.khaChannel = khaChannel;
	}

	public function play(retrigger: Bool) {
		paused = false;
		finished = false;
		khaChannel.play();
		if (retrigger) {
			khaChannel.position = 0;
		}
	}

	public function pause() {
		paused = true;
		khaChannel.pause();
	}

	public function stop() {
		finished = true;
		khaChannel.stop();
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {
		if (!BufferCache.getBuffer(TFloat32Array, p_khaBuffer, 1, requestedSamples.numChannels * requestedSamples.channelLength)) {
			requestedSamples.clear();
			return;
		}
		final khaBuffer = p_khaBuffer.get();

		khaChannel.nextSamples(khaBuffer, requestedSamples.channelLength, sampleRate);
		requestedSamples.deinterleaveFromFloat32Array(khaBuffer, requestedSamples.numChannels);
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a Kha implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: khaChannel.volume = cast message.data;
			case ChannelMessageID.PPitch:
			case ChannelMessageID.PDopplerRatio:
			case ChannelMessageID.PDstAttenuation:

			default:
				super.parseMessage(message);
		}
	}
}
