package auratests.dsp.panner;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Handle;
import aura.Types.Balance;
import aura.dsp.panner.Panner;
import aura.math.Vec3;
import aura.types.AudioBuffer;

import Utils;

private class NonAbstractPanner extends Panner {
	public function process(buffer: AudioBuffer) {}
}

@:access(aura.Handle)
@:access(aura.channels.BaseChannel)
@:access(aura.dsp.panner.Panner)
class TestPanner extends utest.Test {
	var handle: Handle;
	var panner: Panner;

	function setup() {
		handle = Utils.createDummyHandle();
		panner = new NonAbstractPanner(handle);
	}

	function test_calculateDoppler() {
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));

		@:privateAccess aura.Time.delta = 1 / 60;

		Assert.floatEquals(1.0, handle.channel.pDopplerRatio.targetValue);

		panner.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.floatEquals(1.0, handle.channel.pDopplerRatio.targetValue);

		panner.setLocation(new Vec3(1.0, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.isTrue(handle.channel.pDopplerRatio.targetValue < 1.0);

		panner.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		// There is no radial velocity when source and listener are at the same pos
		Assert.floatEquals(1.0, handle.channel.pDopplerRatio.targetValue);

		panner.setLocation(new Vec3(2.0, 0.0, 0.0));
		panner.setLocation(new Vec3(1.0, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.isTrue(handle.channel.pDopplerRatio.targetValue > 1.0);

		@:privateAccess aura.Time.delta = 1.0;

		panner.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(Panner.SPEED_OF_SOUND, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.isTrue(handle.channel.pDopplerRatio.targetValue < 1.0);
		final minRatio = handle.channel.pDopplerRatio.targetValue;

		panner.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(Panner.SPEED_OF_SOUND + 1, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.isTrue(handle.channel.pDopplerRatio.targetValue < 1.0);
		Assert.floatEquals(minRatio, handle.channel.pDopplerRatio.targetValue);

		panner.setLocation(new Vec3(0.5, 0.0, 0.0));
		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.isTrue(handle.channel.pDopplerRatio.targetValue > 1.0);

		// TODO:
		//  check if exactly speed of sound (positive and negative) works
		//  check if faster than speed of sound keeps at speed of sound somehow???
		// Check doppler factor
		// Check if listener moves
	}
}
