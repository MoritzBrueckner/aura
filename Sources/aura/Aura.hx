// =============================================================================
// Based on https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
//
// References:
// [1]: https://github.com/Kode/Kha/blob/3a3e9e6d51b1d6e3309a80cd795860da3ea07355/Backends/Kinc-hxcpp/main.cpp#L186-L233
//
// =============================================================================

package aura;

import haxe.ds.Vector;

import kha.arrays.Float32Array;
import kha.audio2.Audio1;

import aura.channels.MixerChannel;
import aura.channels.ResamplingAudioChannel;
import aura.utils.Assert;
import aura.utils.BufferUtils.clearBuffer;
import aura.utils.MathUtils;

class Aura {
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
		@:privateAccess MixerChannel.channelSize = channelSize;

		listener = new Listener();

		masterChannel = new MixerChannel();
		var musicChannel = new MixerChannel();
		var fxChannel = new MixerChannel();

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

	public static function play(sound: kha.Sound, loop: Bool = false, mixerChannel: Null<MixerChannel> = null): Null<ResamplingAudioChannel> {
		if (mixerChannel == null) {
			mixerChannel = masterChannel;
		}

		assert(sound.uncompressedData != null, Critical);

		// TODO: Like Kha, only use resampling channel if pitch is used or if samplerate of sound and system differs
		var channel = new ResamplingAudioChannel(loop, sound.sampleRate, mixerChannel);
		@:privateAccess channel.data = sound.uncompressedData;

		var foundChannel = mixerChannel.addInputChannel(channel);

		return foundChannel ? channel : null;
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

		var samples = samplesBox.value;

		var sampleCache = getSampleCache(0, samples);

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

		clearBuffer(sampleCache, samples);

		// Copy reference to masterChannel for some more thread safety.
		// TODO: Investigate if other solutions are required here
		var master = masterChannel;

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
