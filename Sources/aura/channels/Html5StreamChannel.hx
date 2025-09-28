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
import js.lib.ArrayBuffer;

import kha.SystemImpl;
import kha.js.MobileWebAudio;
import kha.js.MobileWebAudioChannel;

import aura.Aura;
import aura.format.audio.OggVorbisReader;
import aura.threading.Message;
import aura.types.AudioBuffer;

using StringTools;

using aura.format.BytesExtension;

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

	var audioContext: AudioContext;
	var audioElement: AudioElement;
	var source: MediaElementAudioSourceNode;

	var leftGain: GainNode;
	var rightGain: GainNode;
	var attenuationGain: GainNode;
	var splitter: ChannelSplitterNode;
	var merger: ChannelMergerNode;

	var virtualPosition: Float;
	var lastUpdateTime: Float;

	var dopplerRatio: Float = 1.0;
	var pitch: Float = 1.0;

	public function new(sound: kha.Sound, loop: Bool, parentChannel: MixChannel) {
		audioContext = Aura.audioContext;
		audioElement = Browser.document.createAudioElement();
		source = audioContext.createMediaElementSource(audioElement);

		final mimeType = #if kha_debug_html5 "audio/ogg" #else "audio/mp4" #end;
		final soundData: ArrayBuffer = sound.compressedData.getData();
		final blob = new js.html.Blob([soundData], {type: mimeType});

		// TODO: if removing channels, use revokeObjectUrl() ?
		// 	see https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL
		audioElement.src = URL.createObjectURL(blob);
		audioElement.loop = loop;
		untyped audioElement.preservesPitch = false;
		audioElement.addEventListener("ended", () -> {
			stop();
		});

		splitter = audioContext.createChannelSplitter(2);
		leftGain = audioContext.createGain();
		rightGain = audioContext.createGain();
		attenuationGain = audioContext.createGain();
		merger = audioContext.createChannelMerger(2);
		gain = audioContext.createGain();

		source.connect(splitter);

		// TODO: add more cases for Quad and 5.1 ? - https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Basic_concepts_behind_Web_Audio_API#audio_channels
		switch (sound.channels) {
			case 1:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 0);
			case 2:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 1);
			default:
				throw 'Unsupported channel count: ${sound.channels}';
		}

		leftGain.connect(merger, 0, 0);
		rightGain.connect(merger, 0, 1);
		merger.connect(attenuationGain);
		attenuationGain.connect(gain);

		gain.connect(parentChannel.gain);

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

	/**
		For manual clean up when `BaseChannelHandle.setMixChannel(null)` is used.
		Useful e.g. when changing scenes in Armory.

		Usage: `#if (kha_html5 || kha_debug_html5) untyped cast(@:privateAccess BaseChannelHandle.channel).cleanUp(); #end`.
	**/
	@:keep public function cleanUp() {
		source.disconnect();
		splitter.disconnect();
		leftGain.disconnect();
		rightGain.disconnect();
		merger.disconnect();
		attenuationGain.disconnect();
		gain.disconnect();
		audioElement.pause();
		audioElement.src = "";
		URL.revokeObjectURL(audioElement.src);

		source = null;
		splitter = null;
		leftGain = null;
		rightGain = null;
		merger = null;
		attenuationGain = null;
		gain = null;
		audioElement = null;
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: gain.gain.value = cast message.data;
			case ChannelMessageID.PPitch:
				pitch = cast message.data;
				updatePlaybackRate();
			case ChannelMessageID.PDopplerRatio:
				dopplerRatio = cast message.data;
				updatePlaybackRate();
			case ChannelMessageID.PDstAttenuation: attenuationGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeLeft: leftGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeRight: rightGain.gain.value = cast message.data;

			default:
				super.parseMessage(message);
		}
	}

	function updatePlaybackRate() {
		try {
			audioElement.playbackRate = pitch * dopplerRatio;
		}
		catch (e) {
			// Ignore. Unfortunately some browsers only support a certain range
			// of playback rates, but this is not explicitly specified, so there's
			// not much we can do here.
		}
	}
}

/**
	Wrapper around kha.js.MobileWebAudioChannel.
	See https://github.com/Kode/Kha/issues/299 and
	https://github.com/Kode/Kha/commit/12494b1112b64e4286b6a2fafc0f08462c1e7971
**/
class Html5MobileStreamChannel extends BaseChannel {
	var audioContext: AudioContext;
	var khaChannel: kha.js.MobileWebAudioChannel;
	var parentChannel: MixChannel;

	var leftGain: GainNode;
	var rightGain: GainNode;
	var attenuationGain: GainNode;
	var splitter: ChannelSplitterNode;
	var merger: ChannelMergerNode;

	var dopplerRatio: Float = 1.0;
	var pitch: Float = 1.0;

	public function new(sound: kha.Sound, loop: Bool, pc: MixChannel) {
		audioContext = Aura.audioContext;
		khaChannel = new kha.js.MobileWebAudioChannel(cast sound, loop);
		parentChannel = pc;

		splitter = audioContext.createChannelSplitter(2);
		leftGain = audioContext.createGain();
		rightGain = audioContext.createGain();
		merger = audioContext.createChannelMerger(2);
		attenuationGain = audioContext.createGain();

		// TODO: add more cases for Quad and 5.1 ? - https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Basic_concepts_behind_Web_Audio_API#audio_channels
		switch (sound.channels) {
			case 1:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 0);
			case 2:
				splitter.connect(leftGain, 0);
				splitter.connect(rightGain, 1);
			default:
				throw 'Unsupported channel count: ${sound.channels}';
		}

		leftGain.connect(merger, 0, 0);
		rightGain.connect(merger, 0, 1);
		merger.connect(attenuationGain);
		attenuationGain.connect(@:privateAccess khaChannel.gain);

		reconnectKhaChannelNodes();
	}

	public function play(retrigger: Bool) {
		if (retrigger) {
			khaChannel.position = 0;
		}

		@:privateAccess khaChannel.source.onended = null;
		khaChannel.play();
		// `MobileWebAudioChannel` recreates a 'source' when `khaChannel.play()` is called
		// Reconnect 'source' and 'gain' to the proper nodes
		reconnectKhaChannelNodes();

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

	/**
		For manual clean up when `BaseChannelHandle.setMixChannel(null)` is used.
		Useful e.g. when changing scenes in Armory.

		Usage: `#if (kha_html5 || kha_debug_html5) untyped cast(@:privateAccess BaseChannelHandle.channel).cleanUp(); #end`.
	**/
	@:keep public function cleanUp() {
		@:privateAccess khaChannel.source.onended = null;
		@:privateAccess khaChannel.source.disconnect();
		splitter.disconnect();
		leftGain.disconnect();
		rightGain.disconnect();
		merger.disconnect();
		attenuationGain.disconnect();
		@:privateAccess khaChannel.gain.disconnect();
		khaChannel.stop();

		@:privateAccess khaChannel.gain = null;
		@:privateAccess khaChannel.source = null;
		splitter = null;
		leftGain = null;
		rightGain = null;
		merger = null;
		attenuationGain = null;
		khaChannel = null;
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {}

	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: khaChannel.volume = cast message.data;
			case ChannelMessageID.PPitch:
				pitch = cast message.data;
				updatePlaybackRate();
			case ChannelMessageID.PDopplerRatio:
				dopplerRatio = cast message.data;
				updatePlaybackRate();
			case ChannelMessageID.PDstAttenuation: attenuationGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeLeft: leftGain.gain.value = cast message.data;
			case ChannelMessageID.PVolumeRight: rightGain.gain.value = cast message.data;

			default:
				super.parseMessage(message);
		}
	}

	function updatePlaybackRate() {
		try {
			@:privateAccess khaChannel.source.playbackRate.value = pitch * dopplerRatio;
		}
		catch (e) {}
	}

	function reconnectKhaChannelNodes() {
		@:privateAccess khaChannel.gain.disconnect();
		@:privateAccess khaChannel.source.disconnect();
		@:privateAccess khaChannel.source.connect(splitter);
		@:privateAccess khaChannel.source.onended = stop;
		@:privateAccess khaChannel.gain.connect(parentChannel.gain);
	}
}

function initializeChannelCount(sound: kha.Sound, done: Void->Void) {
	/*
		Peek into the file to detect the file format, Kha sadly does not expose
		this information.

		Using `Reflect.field(kha.Assets.sounds, soundName + "Description").files`
		(i.e. the data in files.json generated by Khamake) would introduce a
		dependency on Kha internals: A `kha.Sound` can be backed by multiple
		exported files and Kha's `LoaderImpl` decides on the order in which
		those files are tried to be loaded.
	*/
	final isOgg = sound.compressedData.isByteMagic(0, "OggS");
	if (isOgg) {
		final oggReader = new OggVorbisReader(sound.compressedData);
		sound.channels = oggReader.getNumChannels();
		done();
	}
	else {
		/*
			In case of other formats, try to let the JS runtime decode the
			entire sound data.

			HACK: decodeAudioData() detaches the array buffer but requires a
			non-detached buffer, so a clone is made to ensure that the array
			buffer of sound.compressedData is never detached and can still be
			used by other code.
		*/
		final soundDataClone: ArrayBuffer = sound.compressedData.getData().slice(0);
		kha.audio2.Audio._context.decodeAudioData(soundDataClone, function (buffer) {
			sound.channels = buffer.numberOfChannels;
			done();
		});
	}
}

#end
