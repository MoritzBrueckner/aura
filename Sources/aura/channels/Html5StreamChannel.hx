package aura.channels;

import kha.arrays.Float32Array;

#if (kha_html5 || kha_debug_html5)
/**
	Wrapper around `kha.js.AEAudioChannel` (for now).
**/
class Html5StreamChannel extends BaseChannel {
	final khaChannel: kha.js.AEAudioChannel;

	public function new(khaChannel: kha.js.AEAudioChannel) {
		this.khaChannel = khaChannel;
	}

	public function play() {
		khaChannel.play();
	}

	public function pause() {
		khaChannel.pause();
	}

	public function stop() {
		khaChannel.stop();
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {
		// khaChannel.nextSamples(requestedSamples, requestedLength, sampleRate);
	}

	function synchronize() {
		var message: Null<Message>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a Kha implementation here, we cannot use the
			// LinearInterpolator parameters
			case PVolume: khaChannel.volume = cast message.data;
			case PBalance:
			case PDopplerRatio:
			case PDstAttenuation:

			default:
				super.parseMessage(message);
		}
	}
}
#end
