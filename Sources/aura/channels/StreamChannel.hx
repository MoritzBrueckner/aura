package aura.channels;

import kha.arrays.Float32Array;

import aura.threading.Message;

/**
	Wrapper around `kha.audio2.StreamChannel` (for now).
**/
class StreamChannel extends BaseChannel {
	final khaChannel: kha.audio2.StreamChannel;

	public function new(khaChannel: kha.audio2.StreamChannel) {
		this.khaChannel = khaChannel;
	}

	public function play() {
		paused = false;
		finished = false;
		khaChannel.play();
	}

	public function pause() {
		paused = true;
		khaChannel.pause();
	}

	public function stop() {
		finished = true;
		khaChannel.stop();
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {
		khaChannel.nextSamples(requestedSamples, requestedLength, sampleRate);
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a Kha implementation here, we cannot use the
			// LinearInterpolator parameters
			case PVolume: khaChannel.volume = cast message.data;
			case PBalance:
			case PPitch:
			case PDopplerRatio:
			case PDstAttenuation:

			default:
				super.parseMessage(message);
		}
	}
}
