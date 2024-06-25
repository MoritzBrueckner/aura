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

@:access(aura.dsp.SparseConvolver.SparseImpulseBuffer)
class TestSparseImpulseBuffer extends utest.Test {
	var buffer: SparseImpulseBuffer;

	function setup() {
		buffer = new SparseImpulseBuffer(4);
	}

	function test_length() {
		Assert.equals(1, new SparseImpulseBuffer(1).length);
		Assert.equals(2, new SparseImpulseBuffer(2).length);
		Assert.equals(3, new SparseImpulseBuffer(3).length);
		Assert.equals(1024, new SparseImpulseBuffer(1024).length);
	}

	function test_impulsePos_notOverwrittenByOtherImpulses() {
		buffer.setImpulsePos(0, 3);
		buffer.setImpulsePos(1, 9);
		buffer.setImpulsePos(2, 17);
		buffer.setImpulsePos(3, 42);

		Assert.equals(3, buffer.getImpulsePos(0));
		Assert.equals(9, buffer.getImpulsePos(1));
		Assert.equals(17, buffer.getImpulsePos(2));
		Assert.equals(42, buffer.getImpulsePos(3));
	}

	function test_impulseMagnitude_notOverwrittenByOtherImpulses() {
		buffer.setImpulseMagnitude(0, 0.3);
		buffer.setImpulseMagnitude(1, 0.9);
		buffer.setImpulseMagnitude(2, 0.17);
		buffer.setImpulseMagnitude(3, 0.42);

		Assert.floatEquals(0.3, buffer.getImpulseMagnitude(0));
		Assert.floatEquals(0.9, buffer.getImpulseMagnitude(1));
		Assert.floatEquals(0.17, buffer.getImpulseMagnitude(2));
		Assert.floatEquals(0.42, buffer.getImpulseMagnitude(3));
	}
}
