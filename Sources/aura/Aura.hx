// =============================================================================
// Based on https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
//
// References:
// [1]: https://github.com/Kode/Kha/blob/3a3e9e6d51b1d6e3309a80cd795860da3ea07355/Backends/Kinc-hxcpp/main.cpp#L186-L233
//
// =============================================================================

package aura;

import aura.utils.Fifo;
import haxe.ds.Vector;

import kha.Assets;
import kha.arrays.Float32Array;
import kha.audio2.Audio1;

import aura.channels.MixerChannel;
import aura.channels.ResamplingAudioChannel;
import aura.utils.Assert;
import aura.utils.BufferUtils.clearBuffer;
import aura.utils.MathUtils;

class Aura {
	public static var sampleRate(default, null): Int;

	public static var listener: Listener;

	public static var mixChannels: Map<String, MixerChannel>;
	public static var masterChannel: MixerChannel;

	public static var sampleCaches: Vector<kha.arrays.Float32Array>;

	/**
		Number of audioCallback() invocations since the last allocation. This is
		used to automatically switch off interactions with the garbage collector
		in the audio thread if there are no allocations for some time (for extra
		performance).
	**/
	static var lastAllocationTimer: Int = 0;

	public static function init(channelSize: Int = 16) {
		sampleRate = kha.audio2.Audio.samplesPerSecond;

		@:privateAccess MixerChannel.channelSize = channelSize;

		listener = new Listener();

		masterChannel = new MixerChannel();
		final musicChannel = new MixerChannel();
		final fxChannel = new MixerChannel();

		mixChannels = [
			"master" => masterChannel,
			"music" => musicChannel,
			"fx" => fxChannel,
		];

		masterChannel.addInputChannel(musicChannel);
		masterChannel.addInputChannel(fxChannel);

		// TODO: Make max tree height configurable
		sampleCaches = new Vector(8);

		kha.audio2.Audio.audioCallback = audioCallback;
	}

	public static function loadSounds(sounds: AuraLoadConfig, done: Void->Void, ?failed: Void->Void) {
		final length = sounds.compressed.length + sounds.uncompressed.length;
		var count = 0;

		try {
			for (soundName in sounds.compressed) {
				Assets.loadSound(soundName, (sound: kha.Sound) -> {
					if (sound.compressedData == null) {
						throw 'Cannot compress already uncompressed sound ${soundName}!';
					}

					if (++count == length) {
						done();
						return;
					}
				});
			}

			for (soundName in sounds.uncompressed) {
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
				});
			}
		}
		catch (e) {
			trace(
				"Could not load sounds, make sure that all sounds are named\n"
				+ "  correctly and that they are included in the khafile.js.\n"
				+ "Original error: " + e.details()
			);

			if (failed != null) {
				failed();
			}
		}
	}

	public static inline function getSound(soundName: String): Null<kha.Sound> {
		return Assets.sounds.get(soundName);
	}

	public static function play(sound: kha.Sound, loop: Bool = false, mixerChannel: Null<MixerChannel> = null): Null<Handle> {
		if (mixerChannel == null) {
			mixerChannel = masterChannel;
		}

		assert(Critical, sound.uncompressedData != null);

		// TODO: Like Kha, only use resampling channel if pitch is used or if samplerate of sound and system differs
		final channel = new ResamplingAudioChannel(loop, sound.sampleRate, mixerChannel);
		@:privateAccess channel.data = sound.uncompressedData;

		final foundChannel = mixerChannel.addInputChannel(channel);

		return foundChannel ? new Handle(channel) : null;
	}

	public static function getSampleCache(treeLevel: Int, length: Int): Null<Float32Array> {
		var cache = sampleCaches[treeLevel];

		if (cache == null || cache.length < length) {
			if (kha.audio2.Audio.disableGcInteractions) {
				// This code is executed in the case that there are suddenly
				// more samples requested while the GC interactions are turned
				// off (because the number samples was sufficient for a longer
				// time). We can't just turn on GC interactions, it will not
				// take effect before the next audio callback invocation, so we
				// skip this "frame" instead (see [1] for reference).

				trace("Unexpected allocation request in audio thread.");

				lastAllocationTimer = 0;
				kha.audio2.Audio.disableGcInteractions = false;
				return null;
			}

			// Overallocate cache by factor 2 to avoid too many allocations,
			// eventually the cache will be big enough for the required amount
			// of samples.
			sampleCaches[treeLevel] = cache = new Float32Array(length * 2);
			lastAllocationTimer = 0;
		}
		else {
			if (lastAllocationTimer > 100) {
				kha.audio2.Audio.disableGcInteractions = true;
			}
			else {
				lastAllocationTimer += 1;
			}
		}

		return cache;
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
		final sampleCache = getSampleCache(0, samples);

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
		var master = masterChannel;
		master.synchronize();

		clearBuffer(sampleCache, samples);

		if (master != null) {
			master.nextSamples(sampleCache, samples, buffer.samplesPerSecond);
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

@:structInit
class AuraLoadConfig {
	public final compressed: Array<String> = [];
	public final uncompressed: Array<String> = [];
}
