package auratests;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Aura;
import aura.Types.Hertz;
import aura.types.AudioBuffer;
import aura.utils.BufferUtils;

import Utils;

class StaticValueGenerator extends aura.channels.generators.BaseGenerator {
	public var counter = 0;

	inline function new() {}

	public static function create(): BaseChannelHandle {
		return new BaseChannelHandle(new StaticValueGenerator());
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz) {
		for (i in 0...requestedSamples.channelLength) {
			for (c in 0...requestedSamples.numChannels) {
				requestedSamples.getChannelView(c)[i] = (++counter) / 4096;
			}
		}
	}
}


@:access(aura.Aura)
class TestAura extends utest.Test {
	final staticInput = StaticValueGenerator.create();

	function setup() {
		staticInput.play();
		@:privateAccess (cast staticInput.channel: StaticValueGenerator).counter = 0;
		Aura.blockBufPos = 0;
	}

	function teardown() {
		staticInput.setMixChannel(null);
	}

	function test_audioCallback_zeroIfNoInput() {
		final compareArray = createEmptyF32Array(Aura.BLOCK_SIZE);

		final buffer = new kha.audio2.Buffer(Aura.BLOCK_SIZE, 2, 44100);
		fillBuffer(buffer.data, -1.0); // Poison buffer

		Aura.audioCallback(new kha.internal.IntBox(Aura.BLOCK_SIZE), buffer);
		assertEqualsFloat32Array(compareArray, buffer.data);
	}

	function test_audioCallback_zeroIfNoSampleCache() {
		final compareArray = createEmptyF32Array(Aura.BLOCK_SIZE);

		staticInput.setMixChannel(Aura.masterChannel);

		// Force sampleCache to be null
		Aura.p_samplesBuffer.set(null);
		kha.audio2.Audio.disableGcInteractions = true;

		final buffer = new kha.audio2.Buffer(Aura.BLOCK_SIZE, 2, 44100);
		fillBuffer(buffer.data, -1.0); // Poison buffer

		Aura.audioCallback(new kha.internal.IntBox(Aura.BLOCK_SIZE), buffer);
		assertEqualsFloat32Array(compareArray, buffer.data);
	}

	function test_audioCallback_contiguouslyWritesBlocksToOutput() {
		final numRequestedSamples = Aura.BLOCK_SIZE * 2 + 2;

		final compareArray = new Float32Array(numRequestedSamples);
		for (i in 0...compareArray.length) {
			compareArray[i] = (i + 1) / 4096;
		}

		staticInput.setMixChannel(Aura.masterChannel);

		final buffer = new kha.audio2.Buffer(numRequestedSamples, 2, 44100);
		fillBuffer(buffer.data, -1.0); // Poison buffer

		Aura.audioCallback(new kha.internal.IntBox(numRequestedSamples), buffer);
		assertEqualsFloat32Array(compareArray, buffer.data);
	}

	function test_audioCallback_splitLargeBlockOverMultipleCallbacks() {
		final numRequestedSamples = Std.int(Aura.BLOCK_SIZE / 2) - 2;

		final compareArray = new Float32Array(3 * numRequestedSamples);
		for (i in 0...compareArray.length) {
			compareArray[i] = (i + 1) / 4096;
		}

		staticInput.setMixChannel(Aura.masterChannel);

		final buffer = new kha.audio2.Buffer(numRequestedSamples, 2, 44100);
		fillBuffer(buffer.data, -1.0); // Poison buffer
		Aura.audioCallback(new kha.internal.IntBox(numRequestedSamples), buffer);

		assertEqualsFloat32Array(compareArray.subarray(0, numRequestedSamples), buffer.data);

		fillBuffer(buffer.data, -1.0); // Poison buffer
		Aura.audioCallback(new kha.internal.IntBox(numRequestedSamples), buffer);
		assertEqualsFloat32Array(compareArray.subarray(numRequestedSamples, numRequestedSamples * 2), buffer.data);

		fillBuffer(buffer.data, -1.0); // Poison buffer
		Aura.audioCallback(new kha.internal.IntBox(numRequestedSamples), buffer);
		assertEqualsFloat32Array(compareArray.subarray(numRequestedSamples * 2, numRequestedSamples * 3), buffer.data);
	}

	// TODO
	// function test_audioCallback_synchronizesMasterChannel() {}
	// function test_audioCallback_updatesTime() {}
	// function test_audioCallback_numChannelsOtherThanNUM_OUTPUT_CHANNELS() {
		// TODO this needs changes in the audio callback. Too dynamic? But Kha might request this...
	// }
}
