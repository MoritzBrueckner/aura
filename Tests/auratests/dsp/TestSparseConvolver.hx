package auratests.dsp;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Aura;
import aura.dsp.SparseConvolver;
import aura.types.AudioBuffer;
import aura.utils.TestSignals;

@:access(aura.dsp.SparseConvolver)
class TestSparseConvolver extends utest.Test {
	var audioBuffer: AudioBuffer;
	var sparseConvolver: SparseConvolver;

	function setup() {
		audioBuffer = new AudioBuffer(2, 512);
		sparseConvolver = new SparseConvolver(1, 4);
	}

	function test_simpleDelay() {
		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 2 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.cos(i * 2 * Math.PI / audioBuffer.channelLength);
		}

		final impulse = sparseConvolver.impulseBuffer;
		impulse.setImpulsePos(0, 3);
		impulse.setImpulseMagnitude(0, 1.0);

		sparseConvolver.process(audioBuffer);

		final wanted = new AudioBuffer(2, audioBuffer.channelLength);
		for (i in 0...wanted.channelLength) {
			wanted.getChannelView(0)[i] = Math.sin((i - 3) * 2 * Math.PI / wanted.channelLength);
			wanted.getChannelView(1)[i] = Math.cos((i - 3) * 2 * Math.PI / wanted.channelLength);
		}

		for (i in 0...3) {
			Assert.floatEquals(0, audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(0, audioBuffer.getChannelView(1)[i]);
		}

		for (i in 3...wanted.channelLength) {
			Assert.floatEquals(wanted.getChannelView(0)[i], audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(wanted.getChannelView(1)[i], audioBuffer.getChannelView(1)[i]);
		}

		// Overlap
		audioBuffer.clear();
		sparseConvolver.process(audioBuffer);
		for (i in 0...3) {
			Assert.floatEquals(wanted.getChannelView(0)[i], audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(wanted.getChannelView(1)[i], audioBuffer.getChannelView(1)[i]);
		}
		for (i in 3...wanted.channelLength) {
			Assert.floatEquals(0, audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(0, audioBuffer.getChannelView(1)[i]);
		}
	}
}
