// =============================================================================
// audioCallback() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
// =============================================================================

package aura;

import haxe.Exception;
import haxe.ds.Vector;

import kha.SystemImpl;
import kha.arrays.Float32Array;

import aura.channels.Html5StreamChannel;
import aura.channels.MixChannel;
import aura.channels.UncompBufferChannel;
import aura.channels.UncompBufferResamplingChannel;
import aura.channels.StreamChannel;
import aura.format.mhr.MHRReader;
import aura.threading.BufferCache;
import aura.types.AudioBuffer;
import aura.types.HRTF;
import aura.utils.Assert;
import aura.utils.BufferUtils.clearBuffer;
import aura.utils.MathUtils;
import aura.utils.Profiler;
import aura.utils.Pointer;

// Convenience typedefs to auto-import them with this module
typedef BaseChannelHandle = aura.channels.BaseChannel.BaseChannelHandle;
typedef UncompBufferChannelHandle = aura.channels.UncompBufferChannel.UncompBufferChannelHandle;
typedef MixChannelHandle = aura.channels.MixChannel.MixChannelHandle;

@:access(aura.channels.MixChannelHandle)
class Aura {
	public static var options(default, null): Null<AuraOptions> = null;

	public static var sampleRate(default, null): Int;
	public static var lastBufferSize(default, null): Int = 0;

	public static var listener: Listener;

	public static final mixChannels = new Map<String, MixChannelHandle>();
	public static var masterChannel(default, null): MixChannelHandle;

	static inline var BLOCK_SIZE = 1024;
	static inline var NUM_OUTPUT_CHANNELS = 2;
	static inline var BLOCK_CHANNEL_SIZE = Std.int(BLOCK_SIZE / NUM_OUTPUT_CHANNELS);
	static var p_samplesBuffer = new Pointer<Float32Array>(null);
	static var blockBuffer = new AudioBuffer(NUM_OUTPUT_CHANNELS, BLOCK_CHANNEL_SIZE);
	static var blockBufPos = 0;

	static final hrtfs = new Map<String, HRTFData>();

	public static function init(?options: AuraOptions) {
		sampleRate = kha.audio2.Audio.samplesPerSecond;
		assert(Critical, sampleRate != 0, "sampleRate must not be 0!");

		Aura.options = AuraOptions.addDefaults(options);
		@:privateAccess MixChannel.channelSize = Aura.options.channelSize;

		listener = new Listener();

		BufferCache.init();

		// Create a few preconfigured mix channels
		masterChannel = createMixChannel("master");
		createMixChannel("music").setMixChannel(masterChannel);
		createMixChannel("fx").setMixChannel(masterChannel);

		#if (kha_html5 || kha_debug_html5)
		if (kha.SystemImpl.mobile) {
			// kha.js.MobileWebAudio doesn't support a custom audio callback, so
			// manually synchronize all tracks here (note that because of this
			// limitation there are no insert effects supported for mobile audio)
			kha.Scheduler.addTimeTask(masterChannel.getMixChannel().synchronize, 0, 1/60);
		}
		else {
		#end
			kha.audio2.Audio.audioCallback = audioCallback;
		#if (kha_html5 || kha_debug_html5)
		}
		#end

		#if (kha_html5 || kha_debug_html5)
			// Check if virtual html5 stream channels can be made physical
			kha.Scheduler.addBreakableTimeTask(() -> {
				if (kha.SystemImpl.mobileAudioPlaying) {
					Html5StreamChannel.makeChannelsPhysical();
					return BreakTask;
				}
				return ContinueTask;
			}, 0, 1/60);
		#end

		kha.System.notifyOnApplicationState(null, null, null, null, () -> {
			Profiler.shutdown();
		});
	}

	/**
		Returns whether a sound exists and can be loaded.
	**/
	public static inline function doesSoundExist(soundName: String): Bool {
		// Use reflection instead of Asset.sounds.get() to prevent errors on
		// static targets. A sound's description is the sound's entry in
		// files.json and not a kha.Sound, but get() returns a sound which would
		// lead to a invalid cast exception.

		// Relying on Kha internals ("Description" as name) is bad, but there is
		// no good alternative...
		return Reflect.field(kha.Assets.sounds, soundName + "Description") != null;
	}

	/**
		Returns whether a blob exists and can be loaded.
	**/
	public static inline function doesBlobExist(blobName: String): Bool {
		return Reflect.field(kha.Assets.blobs, blobName + "Description") != null;
	}

	public static inline function getSound(soundName: String): Null<aura.Assets.Sound> {
		@:privateAccess return aura.Assets.loadedSounds.get(soundName);
	}

	public static inline function getHRTF(hrtfName: String): Null<aura.Assets.HRTF> {
		return @:privateAccess Assets.loadedHRTFs.get(hrtfName);
	}

	/**
		Create a new audio channel to play an uncompressed and pre-loaded sound, and return a main-thread handle object to the newly created channel.
		The playback of the newly created channel does not start automatically.

		@param sound The _uncompressed_ sound to play by the created channel
		@param loop Whether to loop the playback of the channel
		@param mixChannelHandle (Optional) A handle for the `MixChannel`
			to which to route the audio output of the newly created channel.
			If the parameter is `null` (default), route the channel's output
			to the master channel

		@return A main-thread handle to the newly created channel, or `null`
			if the created channel could not be assigned to the given mix channel
			(e.g. in case of circular dependencies)
	**/
	public static function createUncompBufferChannel(sound: aura.Assets.Sound, loop: Bool = false, mixChannelHandle: Null<MixChannelHandle> = null): Null<UncompBufferChannelHandle> {
		assert(Critical, sound.khaSound.uncompressedData != null,
			"Cannot play a sound with no uncompressed data. Make sure to set the sound's 'compressionBehavior' parameter to 'Uncompress'."
		);

		if (mixChannelHandle == null) {
			mixChannelHandle = masterChannel;
		}

		// TODO: Like Kha, only use resampling channel if pitch is used or if samplerate of sound and system differs
		final newChannel = new UncompBufferResamplingChannel(sound.khaSound.uncompressedData, loop, sound.khaSound.sampleRate);

		final handle = new UncompBufferChannelHandle(newChannel);
		final foundChannel = handle.setMixChannel(mixChannelHandle);
		return foundChannel ? handle : null;
	}

	/**
		Create a new audio channel to play a compressed and pre-loaded sound, and return a main-thread handle object to the newly created channel.
		The playback of the newly created channel does not start automatically.

		@param sound The _compressed_ sound to play by the created channel
		@param loop Whether to loop the playback of the channel
		@param mixChannelHandle (Optional) A handle for the `MixChannel`
			to which to route the audio output of the newly created channel.
			If the parameter is `null` (default), route the channel's output
			to the master channel

		@return A main-thread handle to the newly created channel, or `null`
			if the created channel could not be assigned to the given mix channel
			(e.g. in case of circular dependencies)
	**/
	public static function createCompBufferChannel(sound: aura.Assets.Sound, loop: Bool = false, mixChannelHandle: Null<MixChannelHandle> = null): Null<BaseChannelHandle> {
		#if kha_krom
			// Krom only uses uncompressedData -> no streaming
			return createUncompBufferChannel(sound, loop, mixChannelHandle);
		#end

		assert(Critical, sound.khaSound.compressedData != null,
			"Cannot stream a sound with no compressed data. Make sure to set the sound's 'compressionBehavior' parameter to 'KeepCompressed'."
		);

		if (mixChannelHandle == null) {
			mixChannelHandle = masterChannel;
		}

		#if (kha_html5 || kha_debug_html5)
			final newChannel = kha.SystemImpl.mobile ? new Html5MobileStreamChannel(sound.khaSound, loop) : new Html5StreamChannel(sound.khaSound, loop);
		#else
			final khaChannel: Null<kha.audio1.AudioChannel> = kha.audio2.Audio1.stream(sound.khaSound, loop);
			if (khaChannel == null) {
				return null;
			}
			final newChannel = new StreamChannel(cast khaChannel);
			newChannel.stop();
		#end

		final handle = new BaseChannelHandle(newChannel);
		final foundChannel = handle.setMixChannel(mixChannelHandle);
		return foundChannel ? handle : null;
	}

	/**
		Create a `MixChannel` to control a group of other channels together.
		@param name Optional name. If not empty, the name can be used later to
			retrieve the channel handle via `Aura.mixChannels[name]`.
	**/
	public static inline function createMixChannel(name: String = ""): MixChannelHandle {
		final handle = new MixChannelHandle(new MixChannel());
		if (name != "") {
			assert(Error, !mixChannels.exists(name), 'MixChannel with name $name already exists!');
			mixChannels[name] = handle;
			#if AURA_DEBUG
			handle.name = name;
			#end
		}
		return handle;
	}

	/**
		Mixes all sub channels and sounds in this channel together.

		Based on `kha.audio2.Audio1.mix()`.

		@param samplesBox Wrapper that holds the amount of requested samples.
		@param buffer The buffer into which to write the output samples.
	**/
	static function audioCallback(samplesBox: kha.internal.IntBox, buffer: kha.audio2.Buffer): Void {
		Profiler.frame("AudioCallback");

		Time.update();

		final samplesRequested = samplesBox.value;
		Aura.lastBufferSize = samplesRequested;

		if (!BufferCache.getBuffer(TFloat32Array, p_samplesBuffer, 1, samplesRequested)) {
			for (_ in 0...samplesRequested) {
				buffer.data.set(buffer.writeLocation, 0);
				buffer.writeLocation += 1;
				if (buffer.writeLocation >= buffer.size) {
					buffer.writeLocation = 0;
				}
			}
			return;
		}

		// At this point we can be sure that sampleCache is not null
		final sampleCache = p_samplesBuffer.get();

		// Copy reference to masterChannel for some more thread safety.
		// TODO: Investigate if other solutions are required here
		var master: MixChannel = masterChannel.getMixChannel();
		master.synchronize();

		clearBuffer(sampleCache);

		var samplesWritten = 0;

		// The blockBuffer still has some values from the last audioCallback
		// invocation that haven't been written to the sampleCache yet
		if (blockBufPos != 0) {
			final samplesToWrite = minI(samplesRequested, BLOCK_SIZE - blockBufPos);
			blockBuffer.interleaveToFloat32Array(sampleCache, Std.int(blockBufPos / NUM_OUTPUT_CHANNELS), 0, Std.int(samplesToWrite / NUM_OUTPUT_CHANNELS));
			samplesWritten += samplesToWrite;
			blockBufPos += samplesToWrite;

			if (blockBufPos >= BLOCK_SIZE) {
				blockBufPos = 0;
			}
		}

		while (samplesWritten < samplesRequested) {
			master.nextSamples(blockBuffer, buffer.samplesPerSecond);

			final samplesStillWritable = minI(samplesRequested - samplesWritten, BLOCK_SIZE);
			blockBuffer.interleaveToFloat32Array(sampleCache, 0, samplesWritten, Std.int(samplesStillWritable / NUM_OUTPUT_CHANNELS));
			samplesWritten += samplesStillWritable;
			blockBufPos += samplesStillWritable;

			if (blockBufPos >= BLOCK_SIZE) {
				blockBufPos = 0;
			}
		}

		for (i in 0...samplesRequested) {
			// Write clamped samples to final buffer
			buffer.data.set(buffer.writeLocation, maxF(minF(sampleCache[i], 1.0), -1.0));
			buffer.writeLocation += 1;
			if (buffer.writeLocation >= buffer.size) {
				buffer.writeLocation = 0;
			}
		}

		#if AURA_BENCHMARK
			Time.endOfFrame();
		#end
	}
}

@:structInit
class AuraOptions {
	@:optional public var channelSize: Null<Int>;

	public static function addDefaults(options: Null<AuraOptions>) {
		if (options == null) { options = {}; }

		if (options.channelSize == null) { options.channelSize = 16; }

		return options;
	}
}

private enum abstract BreakableTaskStatus(Bool) to Bool {
	var BreakTask = false;
	var ContinueTask = true;
}
