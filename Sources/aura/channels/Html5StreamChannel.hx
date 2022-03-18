package aura.channels;

import kha.js.MobileWebAudioChannel;
import js.Browser;
import js.html.AudioElement;
import js.html.URL;

import kha.SystemImpl;
import kha.arrays.Float32Array;

import aura.threading.Message;

#if (kha_html5 || kha_debug_html5)
/**
	Channel dedicated for streaming playback on html5.

	Because most browsers don't allow audio playback before the user has
	interacted with the website or canvas at least once, we can't always play
	audio without causing an exception. In order to not cause chaos with sounds
	playing at wrong times, sounds are virtualized before they can actually be
	played. This means that their playback position is tracked and as soon as
	the user interacts with the web page, the audio starts playing at the
	correct position as if the sound would be playing all the time since it was
	started.

	Note that on mobile browsers the `aura.channels.Html5MobileStreamChannel` is
	used instead.
**/
class Html5StreamChannel extends BaseChannel {
	static final virtualChannels: Array<Html5StreamChannel> = [];

	final audioElement: AudioElement;

	var virtualPosition: Float;
	var lastUpdateTime: Float;

	public function new(sound: kha.Sound, loop: Bool) {
		audioElement = Browser.document.createAudioElement();
		final mimeType = #if kha_debug_html5 "audio/ogg" #else "audio/mp4" #end;
		final blob = new js.html.Blob([sound.compressedData.getData()], {type: mimeType});

		// TODO: if removing channels, use revokeObjectUrl() ?
		// 	see https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL
		audioElement.src = URL.createObjectURL(blob);
		audioElement.loop = loop;

		if (isVirtual()) {
			virtualChannels.push(this);
		}
	}

	inline function isVirtual(): Bool {
		return !SystemImpl.mobileAudioPlaying;
	}

	@:allow(aura.Aura)
	static function makeChannelsPhysical() {
		for (channel in virtualChannels) {
			channel.updateVirtualPosition();
			channel.audioElement.currentTime = channel.virtualPosition;

			if (!channel.finished && !channel.paused) {
				channel.audioElement.play();
			}
		}
		virtualChannels.resize(0);
	}

	inline function updateVirtualPosition() {
		final now = kha.Scheduler.realTime();

		if (finished) {
			virtualPosition = 0;
		}
		else if (!paused) {
			virtualPosition += now - lastUpdateTime;
			while (virtualPosition > audioElement.duration) {
				virtualPosition -= audioElement.duration;
			}
		}

		lastUpdateTime = now;
	}

	public function play(retrigger: Bool) {
		if (isVirtual()) {
			updateVirtualPosition();
			if (retrigger) {
				virtualPosition = 0;
			}
		}
		else {
			audioElement.play();
			if (retrigger) {
				audioElement.currentTime = 0;
			}
		}

		paused = false;
		finished = false;
	}

	public function pause() {
		if (isVirtual()) {
			updateVirtualPosition();
		}
		else {
			audioElement.pause();
		}

		paused = true;
	}

	public function stop() {
		if (isVirtual()) {
			updateVirtualPosition();
		}
		else {
			audioElement.pause();
			audioElement.currentTime = 0;
		}

		finished = true;
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {}

	override function parseMessage(message: ChannelMessage) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case PVolume: audioElement.volume = cast message.data;
			case PBalance:
			case PPitch:
			case PDopplerRatio:
			case PDstAttenuation:

			default:
				super.parseMessage(message);
		}
	}
}

/**
	Wrapper around kha.js.MobileWebAudioChannel.
	See https://github.com/Kode/Kha/issues/299 and
	https://github.com/Kode/Kha/commit/12494b1112b64e4286b6a2fafc0f08462c1e7971
**/
class Html5MobileStreamChannel extends BaseChannel {
	final khaChannel: kha.js.MobileWebAudioChannel;

	public function new(sound: kha.Sound, loop: Bool) {
		khaChannel = new kha.js.MobileWebAudioChannel(cast sound, loop);
	}

	public function play(retrigger: Bool) {
		if (retrigger) {
			khaChannel.position = 0;
		}
		khaChannel.play();

		paused = false;
		finished = false;
	}

	public function pause() {
		khaChannel.pause();
		paused = true;
	}

	public function stop() {
		khaChannel.stop();
		finished = true;
	}

	function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz) {}

	override function parseMessage(message: ChannelMessage) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
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
#end
