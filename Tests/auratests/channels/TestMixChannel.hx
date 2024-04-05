package auratests.channels;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Types.Balance;
import aura.channels.MixChannel;
import aura.dsp.sourcefx.SourceEffect;
import aura.types.AudioBuffer;

@:access(aura.channels.MixChannel)
class TestMixChannel extends utest.Test {
	static inline var channelLength = 16;

	var mixChannel: MixChannel;
	var mixChannelHandle: MixChannelHandle;

	function setupClass() {}

	function setup() {
		mixChannel = new MixChannel();
		mixChannelHandle = new MixChannelHandle(mixChannel);
	}

	function teardown() {}

	function test_startUnpausedAndUnfinished() {
		final inputHandle = new MixChannelHandle(new MixChannel());

		Assert.isFalse(mixChannel.paused);
		Assert.isFalse(mixChannel.finished);
	}

	function test_isNotPlayable_ifNoInputChannelExists() {
		Assert.isFalse(mixChannel.isPlayable());
	}

	function test_isPlayable_ifInputChannelExists() {
		final inputHandle = new MixChannelHandle(new MixChannel());

		inputHandle.setMixChannel(mixChannelHandle);

		Assert.isTrue(mixChannel.isPlayable());
	}
}
