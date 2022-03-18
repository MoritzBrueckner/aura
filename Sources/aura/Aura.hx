// =============================================================================
// audioCallback() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
// =============================================================================

package aura;

import haxe.Exception;
import haxe.ds.Vector;

import kha.Assets;
import kha.SystemImpl;
import kha.arrays.Float32Array;
import kha.audio2.Audio1;

import aura.MixChannelHandle;
import aura.channels.Html5StreamChannel;
import aura.channels.MixChannel;
import aura.channels.ResamplingAudioChannel;
import aura.channels.StreamChannel;
import aura.format.mhr.MHRReader;
import aura.threading.BufferCache;
import aura.types.HRTF;
import aura.utils.Assert;
import aura.utils.BufferUtils.clearBuffer;
import aura.utils.MathUtils;

@:access(aura.MixChannelHandle)
class Aura {
	static inline var BLOCK_SIZE = 1024;

	public static var options(default, null): Null<AuraOptions> = null;

	public static var sampleRate(default, null): Int;
	public static var lastBufferSize(default, null): Int = 0;

	public static var listener: Listener;

	public static final mixChannels = new Map<String, MixChannelHandle>();
	public static var masterChannel(default, null): MixChannelHandle;
	static var blockBuffer = new Float32Array(BLOCK_SIZE);
	static var blockBufPos = 0;

	static final hrtfs = new Map<String, HRTF>();

	public static function init(?options: AuraOptions) {
		sampleRate = kha.audio2.Audio.samplesPerSecond;
		assert(Critical, sampleRate != 0, "sampleRate must not be 0!");

		Aura.options = AuraOptions.addDefaults(options);
		@:privateAccess MixChannel.channelSize = Aura.options.channelSize;

		listener = new Listener();

		BufferCache.init();

		// Create a few preconfigured mix channels
		masterChannel = createMixChannel("master");
		masterChannel.addInputChannel(createMixChannel("music"));
		masterChannel.addInputChannel(createMixChannel("fx"));


		if (kha.SystemImpl.mobile) {
			// kha.js.MobileWebAudio doesn't support a custom audio callback, so
			// manually synchronize all tracks here (note that because of this
			// limitation there are no insert effects supported for mobile audio)
			kha.Scheduler.addTimeTask(masterChannel.getMixChannel().synchronize, 0, 1/60);
		}
		else {
			kha.audio2.Audio.audioCallback = audioCallback;
		}

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
	}

	public static function loadAssets(loadConfig: AuraLoadConfig, done: Void->Void, ?failed: Void->Void) {
		final length = loadConfig.getEntryCount();
		var count = 0;

		for (soundName in loadConfig.compressed) {
			if (!doesSoundExist(soundName)) {
				onLoadingError(null, failed, soundName);
				break;
			}
			Assets.loadSound(soundName, (sound: kha.Sound) -> {
				#if !kha_krom // Krom only uses uncompressedData
				if (sound.compressedData == null) {
					throw 'Cannot compress already uncompressed sound ${soundName}!';
				}
				#end

				if (++count == length) {
					done();
					return;
				}
			}, (error: kha.AssetError) -> { onLoadingError(error, failed, soundName); });
		}

		for (soundName in loadConfig.uncompressed) {
			if (!doesSoundExist(soundName)) {
				onLoadingError(null, failed, soundName);
				break;
			}
			Assets.loadSound(soundName, (sound: kha.Sound) -> {
				if (sound.uncompressedData == null) {
					sound.uncompress(() -> {
						if (++count == length) {
							done();
							return;
						}
					});
				}
				else {
					if (++count == length) {
						done();
						return;
					}
				}
			}, (error: kha.AssetError) -> { onLoadingError(error, failed, soundName); });
		}

		for (hrtfName in loadConfig.hrtf) {
			if (!doesBlobExist(hrtfName)) {
				onLoadingError(null, failed, hrtfName);
				break;
			}
			Assets.loadBlob(hrtfName, (blob: kha.Blob) -> {
				final reader = new MHRReader(blob.bytes);
				var hrtf: HRTF;
				try {
					hrtf = reader.read();
				}
				catch (e: Exception) {
					trace('Could not load hrtf $hrtfName: ${e.details()}');
					if (failed != null) {
						failed();
					}
					return;
				}
				hrtfs[hrtfName] = hrtf;
				if (++count == length) {
					done();
					return;
				}
			}, (error: kha.AssetError) -> { onLoadingError(error, failed, hrtfName); });
		}
	}

	static function onLoadingError(error: Null<kha.AssetError>, failed: Null<Void->Void>, assetName: String) {
		final errorInfo = error == null ? "" : "\nOriginal error: " + error.url + "..." + error.error;

		trace(
			'Could not load asset "$assetName", make sure that all assets are named\n'
			+ "  correctly and that they are included in the khafile.js."
			+ errorInfo
		);

		if (failed != null) {
			failed();
		}
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
		return Reflect.field(Assets.sounds, soundName + "Description") != null;
	}

	/**
		Returns whether a blob exists and can be loaded.
	**/
	public static inline function doesBlobExist(blobName: String): Bool {
		return Reflect.field(Assets.blobs, blobName + "Description") != null;
	}

	public static inline function getSound(soundName: String): Null<kha.Sound> {
		return Assets.sounds.get(soundName);
	}

	public static inline function getHRTF(hrtfName: String): Null<HRTF> {
		return hrtfs.get(hrtfName);
	}

	public static function createHandle(playMode: PlayMode, sound: kha.Sound, loop: Bool = false, mixChannelHandle: Null<MixChannelHandle> = null): Null<Handle> {
		if (mixChannelHandle == null) {
			mixChannelHandle = masterChannel;
		}

		#if kha_krom
			// Krom only uses uncompressedData -> no streaming
			playMode = PlayMode.Play;
		#end

		var newChannel: aura.channels.BaseChannel;

		switch (playMode) {
			case Play:
				assert(Critical, sound.uncompressedData != null);

				// TODO: Like Kha, only use resampling channel if pitch is used or if samplerate of sound and system differs
				newChannel = new ResamplingAudioChannel(sound.uncompressedData, loop, sound.sampleRate);

			case Stream:
				assert(Critical, sound.compressedData != null);

				#if (kha_html5 || kha_debug_html5)
					if (kha.SystemImpl.mobile) {
						newChannel = new Html5MobileStreamChannel(sound, loop);
					}
					else {
						newChannel = new Html5StreamChannel(sound, loop);
					}
				#else
					final khaChannel: Null<kha.audio1.AudioChannel> = kha.audio2.Audio1.stream(sound, loop);
					if (khaChannel == null) {
						return null;
					}
					newChannel = new StreamChannel(cast khaChannel);
					newChannel.stop();
				#end
			}

		final handle = new Handle(newChannel);
		final foundChannel = mixChannelHandle.addInputChannel(handle);
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
		Time.update();

		final samples = samplesBox.value;
		Aura.lastBufferSize = samples;
		final sampleCache = BufferCache.getTreeBuffer(0, samples);

		if (sampleCache == null) {
			for (i in 0...samples) {
				buffer.data.set(buffer.writeLocation, 0);
				buffer.writeLocation += 1;
				if (buffer.writeLocation >= buffer.size) {
					buffer.writeLocation = 0;
				}
			}
			return;
		}

		// Copy reference to masterChannel for some more thread safety.
		// TODO: Investigate if other solutions are required here
		var master: MixChannel = masterChannel.getMixChannel();
		master.synchronize();

		clearBuffer(sampleCache, samples);

		if (master != null) {
			var samplesWritten = 0;

			// The last block still has some values to read from
			if (blockBufPos != 0) {
				final offset = blockBufPos;
				for (i in 0...minI(samples, BLOCK_SIZE - blockBufPos)) {
					sampleCache[i] = blockBuffer[offset + i];
					samplesWritten++;
					blockBufPos++;
				}
				if (blockBufPos >= BLOCK_SIZE) {
					blockBufPos = 0;
				}
			}

			while (samplesWritten < samples) {
				master.nextSamples(blockBuffer, BLOCK_SIZE, buffer.samplesPerSecond);

				final offset = samplesWritten;
				for (i in 0...minI(samples - samplesWritten, BLOCK_SIZE)) {
					sampleCache[offset + i] = blockBuffer[i];
					samplesWritten++;
					blockBufPos++;
				}
				if (blockBufPos >= BLOCK_SIZE) {
					blockBufPos = 0;
				}
			}
		}

		for (i in 0...samples) {
			// Write clamped samples to final buffer
			buffer.data.set(buffer.writeLocation, maxF(minF(sampleCache[i], 1.0), -1.0));
			buffer.writeLocation += 1;
			if (buffer.writeLocation >= buffer.size) {
				buffer.writeLocation = 0;
			}
		}
	}
}

@:allow(aura.Aura)
@:structInit
class AuraLoadConfig {
	public final compressed: Array<String> = [];
	public final uncompressed: Array<String> = [];
	public final hrtf: Array<String> = [];

	inline function getEntryCount(): Int {
		return compressed.length + uncompressed.length + hrtf.length;
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

enum abstract PlayMode(Int) {
	var Play;
	var Stream;
}

private enum abstract BreakableTaskStatus(Bool) to Bool {
	var BreakTask = false;
	var ContinueTask = true;
}
