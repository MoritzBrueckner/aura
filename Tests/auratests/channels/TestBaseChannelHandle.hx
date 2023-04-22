package auratests.channels;

import utest.Assert;

import aura.Aura;
import aura.channels.MixChannel;
import aura.channels.UncompBufferResamplingChannel;

class TestBaseChannelHandle extends utest.Test {
	var handle: BaseChannelHandle;
	var channel: UncompBufferResamplingChannel;
	var data = new kha.arrays.Float32Array(8);

	function setup() {
		channel = new UncompBufferResamplingChannel(data, false, 44100);
		handle = new BaseChannelHandle(channel);
	}

	function teardown() {}

	function test_setMixChannelAddsInputIfNotYetExisting() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());

		Assert.equals(0, handle2.getNumInputs());
		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());
	}

	function test_setMixChannelDoesntAddAlreadyExistingInput() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());

		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());
		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());
	}

	function test_setMixChannelNullRemovesInputIfExisting() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());

		Assert.equals(0, handle2.getNumInputs());
		Assert.isTrue(handle1.setMixChannel(null));
		Assert.equals(0, handle2.getNumInputs());

		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());

		Assert.isTrue(handle1.setMixChannel(null));
		Assert.equals(0, handle2.getNumInputs());
	}

	function test_setMixChannelSwitchingMixChannelCorrectlyChangesInputs() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());
		final handle3 = new MixChannelHandle(new MixChannel());

		Assert.equals(0, handle2.getNumInputs());
		Assert.equals(0, handle3.getNumInputs());
		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());
		Assert.equals(0, handle3.getNumInputs());

		Assert.isTrue(handle1.setMixChannel(handle3));
		Assert.equals(0, handle2.getNumInputs());
		Assert.equals(1, handle3.getNumInputs());
	}

	function test_setMixChannelSelfReferenceReturnsFalseAndRemovesInput() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());

		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.equals(1, handle2.getNumInputs());

		Assert.isFalse(handle1.setMixChannel(handle1));
		Assert.equals(0, handle2.getNumInputs());
	}

	function test_setMixChannelCircularDependencyReturnsFalseAndRemovesInput() {
		final handle1 = new MixChannelHandle(new MixChannel());
		final handle2 = new MixChannelHandle(new MixChannel());
		final handle3 = new MixChannelHandle(new MixChannel());
		final handle4 = new MixChannelHandle(new MixChannel());

		Assert.isTrue(handle3.setMixChannel(handle4));

		Assert.isTrue(handle1.setMixChannel(handle2));
		Assert.isTrue(handle2.setMixChannel(handle3));
		Assert.isFalse(handle3.setMixChannel(handle1));
		Assert.equals(0, handle4.getNumInputs());
	}
}
