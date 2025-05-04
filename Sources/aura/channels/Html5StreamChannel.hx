package aura.channels;

#if (kha_html5 || kha_debug_html5)

import js.Browser;
import js.html.AudioElement;
import js.html.audio.AudioContext;
import js.html.audio.ChannelSplitterNode;
import js.html.audio.ChannelMergerNode;
import js.html.audio.GainNode;
import js.html.audio.MediaElementAudioSourceNode;
import js.html.URL;

import kha.SystemImpl;
import kha.js.MobileWebAudio;
import kha.js.MobileWebAudioChannel;

import aura.threading.Message;
import aura.types.AudioBuffer;

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

	final audioContext: AudioContext;
	final audioElement: AudioElement;
	final source: MediaElementAudioSourceNode;

	final gain: GainNode;
	final leftGain: GainNode;
	final rightGain: GainNode;
	final attenuationGain: GainNode;
	final splitter: ChannelSplitterNode;
	final merger: ChannelMergerNode;

	var virtualPosition: Float;
	var lastUpdateTime: Float;

	var dopplerRatio: Float = 1.0;

	public function new(sound: kha.Sound, loop: Bool) {
		audioContext = new AudioContext();
		audioElement = Browser.document.createAudioElement();
		source = audioContext.createMediaElementSource(audioElement);

		final mimeType = #if kha_debug_html5 "audio/ogg" #else "audio/mp4" #end;
		final soundData: js.lib.ArrayBuffer = sound.compressedData.getData();
		final blob = new js.html.Blob([soundData], {type: mimeType});
		
		// TODO: if removing channels, use revokeObjectUrl() ?
		// 	see https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL
		audioElement.src = URL.createObjectURL(blob);
		audioElement.loop = loop;
		untyped audioElement.preservesPitch = false;

		splitter = audioContext.createChannelSplitter(2);
		leftGain = audioContext.createGain();
		rightGain = audioContext.createGain();
		attenuationGain = audioContext.createGain();
		merger = audioContext.createChannelMerger(2);
		gain = audioContext.createGain();

		source.connect(splitter);

		// The sound data needs to be decoded because `sounds.channels` returns `0`.
		audioContext.decodeAudioData(soundData, function (buffer) {
			// TODO: add more cases for Quad and 5.1 ? - https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Basic_concepts_behind_Web_Audio_API#audio_channels
			switch (buffer.numberOfChannels) {
				case 1:
					splitter.connect(leftGain, 0);
					splitter.connect(rightGain, 0);
				case 2:
					splitter.connect(leftGain, 0);
					splitter.connect(rightGain, 1);
				default:
			}
		});

		leftGain.connect(merger, 0, 0);
		rightGain.connect(merger, 0, 1);
		merger.connect(attenuationGain);
		attenuationGain.connect(gain);
		
		gain.connect(audioContext.destination);

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

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: attenuationGain.gain.value = cast message.data;
			case ChannelMessageID.PPitch: audioElement.playbackRate = dopplerRatio * cast message.data;
			case ChannelMessageID.PDopplerRatio: dopplerRatio = cast message.data;
			case ChannelMessageID.PDstAttenuation: gain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeLeft: leftGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeRight: rightGain.gain.value = cast message.data;

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
	final audioContext: AudioContext;
	final khaChannel: kha.js.MobileWebAudioChannel;

	final leftGain: GainNode;
	final rightGain: GainNode;
	final attenuationGain: GainNode;
	final splitter: ChannelSplitterNode;
	final merger: ChannelMergerNode;

	var dopplerRatio: Float = 1.0;

	public function new(sound: kha.Sound, loop: Bool) {
		audioContext = MobileWebAudio._context;
		khaChannel = new kha.js.MobileWebAudioChannel(cast sound, loop);

		@:privateAccess khaChannel.gain.disconnect(audioContext.destination);
		@:privateAccess khaChannel.source.disconnect(@:privateAccess khaChannel.gain);
		
		splitter = audioContext.createChannelSplitter(2);
		leftGain = audioContext.createGain();
		rightGain = audioContext.createGain();
		merger = audioContext.createChannelMerger(2);
		attenuationGain = audioContext.createGain();
		
		@:privateAccess khaChannel.source.connect(splitter);

		// TODO: add more cases for Quad and 5.1 ? - https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Basic_concepts_behind_Web_Audio_API#audio_channels
		switch (sound.channels) {
			case 1:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 0);
			case 2:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 1);
			default:
		}

		leftGain.connect(merger, 0, 0);
		rightGain.connect(merger, 0, 1);
		merger.connect(attenuationGain);
		attenuationGain.connect(@:privateAccess khaChannel.gain);
		
		@:privateAccess khaChannel.gain.connect(audioContext.destination);
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

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: khaChannel.volume = cast message.data;
			case ChannelMessageID.PPitch: @:privateAccess khaChannel.source.playbackRate.value = dopplerRatio * cast message.data;
			case ChannelMessageID.PDopplerRatio: dopplerRatio = cast message.data;
			case ChannelMessageID.PDstAttenuation: attenuationGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeLeft: leftGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeRight: rightGain.gain.value = cast message.data;

			default:
				super.parseMessage(message);
		}
	}
}
#end
