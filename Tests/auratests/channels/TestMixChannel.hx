package auratests.channels;

import utest.Assert;

import aura.channels.MixChannel;

@:access(aura.channels.MixChannel)
class TestMixChannel extends utest.Test {
	var mixChannel: MixChannel;
	var mixChannelHandle: MixChannelHandle;

	function setupClass() {}

	function setup() {
		mixChannel = new MixChannel();
		mixChannelHandle = new MixChannelHandle(mixChannel);
	}

	function teardown() {}

	function test_startUnpausedAndUnfinished() {
		// Regression test for https://github.com/MoritzBrueckner/aura/issues/7

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
