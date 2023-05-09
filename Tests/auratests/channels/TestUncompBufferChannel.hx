package auratests.channels;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Types.Balance;
import aura.channels.UncompBufferChannel;
import aura.dsp.sourcefx.SourceEffect;
import aura.types.AudioBuffer;

@:access(aura.channels.UncompBufferChannel)
class TestUncompBufferChannel extends utest.Test {
	static inline var channelLength = 16;

	var audioChannel: UncompBufferChannel;
	var sourceFX1: SourceFXDummy;
	var sourceFX2: SourceFXDummy;

	final data = new Float32Array(2 * channelLength);

	function setupClass() {}

	function setup() {
		audioChannel = new UncompBufferChannel(data, false);
		sourceFX1 = new SourceFXDummy();
		sourceFX2 = new SourceFXDummy();

		audioChannel.addSourceEffect(sourceFX1);
		audioChannel.addSourceEffect(sourceFX2);
	}

	function teardown() {}

	function test_optionallyApplySourceEffects_isAppliedOnFirstPlay_ifNoEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(false);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);

		audioChannel.play(false);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isAppliedOnFirstPlay_ifAnyEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(true);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);

		audioChannel.play(false);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);
	}


	function test_optionallyApplySourceEffects_isNotAppliedOnSecondPlayAfterFinish_ifNoEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(false);

		audioChannel.play(false);
		audioChannel.stop();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(false);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isAppliedOnSecondPlayAfterFinish_ifAnyEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(true);

		audioChannel.play(false);
		audioChannel.stop();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(false);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isNotAppliedOnPlayAfterPause_ifNoEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(false);

		audioChannel.play(false);
		audioChannel.pause();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(false);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isNotAppliedOnPlayAfterPause_ifAnyEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(true);

		audioChannel.play(false);
		audioChannel.pause();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(false);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isNotAppliedOnRetrigger_ifNoEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(false);

		audioChannel.play(false);

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(true);

		Assert.isFalse(sourceFX1.wasProcessCalled);
		Assert.isFalse(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isAppliedOnRetrigger_ifAnyEffectIsConfiguredToApplyOnReplay() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(true);

		audioChannel.play(false);

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.play(true);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);
	}

	function test_optionallyApplySourceEffects_isAppliedOnConsecutivePlays_ifEffectsHaveChanged() {
		sourceFX1.applyOnReplay.store(false);
		sourceFX2.applyOnReplay.store(false);

		audioChannel.play(false);
		audioChannel.stop();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		final tempSourceFX = new SourceFXDummy();
		audioChannel.addSourceEffect(tempSourceFX);

		audioChannel.play(false);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);

		audioChannel.stop();

		sourceFX1.wasProcessCalled = false;
		sourceFX2.wasProcessCalled = false;

		audioChannel.removeSourceEffect(tempSourceFX);

		audioChannel.play(false);

		Assert.isTrue(sourceFX1.wasProcessCalled);
		Assert.isTrue(sourceFX2.wasProcessCalled);
	}

	function test_nextSamples_onLoop_ApplySourceEffectsOnce() {
		audioChannel.looping = true;

		Assert.equals(0, sourceFX1.numProcessCalled);
		Assert.equals(0, sourceFX2.numProcessCalled);

		final outBuffer = new AudioBuffer(2, channelLength + 1);
		audioChannel.nextSamples(outBuffer, 1000);

		// Make sure process is only called once for _all_ channels
		Assert.equals(1, sourceFX1.numProcessCalled);
		Assert.equals(1, sourceFX2.numProcessCalled);
	}
}


private class SourceFXDummy extends SourceEffect {
	public var wasProcessCalled = false;
	public var numProcessCalled = 0;

	public function new() {}

	function calculateRequiredChannelLength(srcChannelLength: Int): Int {
		return srcChannelLength;
	}

	function process(srcBuffer: AudioBuffer, srcChannelLength: Int, dstBuffer: AudioBuffer): Int {
		wasProcessCalled = true;
		numProcessCalled++;
		return srcChannelLength;
	}
}
