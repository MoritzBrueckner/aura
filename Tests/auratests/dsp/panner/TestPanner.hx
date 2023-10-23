package auratests.dsp.panner;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Aura;
import aura.Time;
import aura.Types.Balance;
import aura.dsp.panner.Panner;
import aura.math.Vec3;
import aura.types.AudioBuffer;

import Utils;

private class NonAbstractPanner extends Panner {
	public function process(buffer: AudioBuffer) {}
}

@:access(aura.channels.BaseChannel)
@:access(aura.channels.BaseChannelHandle)
@:access(aura.dsp.panner.Panner)
class TestPanner extends utest.Test {
	var handle: BaseChannelHandle;
	var panner: Panner;

	function setup() {
		handle = Utils.createDummyHandle();
		panner = new NonAbstractPanner(handle);

		@:privateAccess panner.initializedLocation = false;
		@:privateAccess aura.Aura.listener.initializedLocation = false;
	}

	function teardown() {
		Time.overrideTime = null;
	}

	function test_noDopplerEffect_ifNoMovement() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.floatEquals(1.0, handle.channel.pDopplerRatio.targetValue);

		@:privateAccess panner.initializedLocation = false;
		@:privateAccess aura.Aura.listener.initializedLocation = false;

		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(5.0, 4.0, 3.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(5.0, 4.0, 3.0));

		panner.calculateDoppler();
		handle.channel.synchronize();
		Assert.floatEquals(1.0, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_physicallyCorrectValues_pannerMovesAway() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(2.0, 0.0, 0.0));

		Assert.floatEquals(4.0, @:privateAccess panner.velocity.length);
		Assert.floatEquals(0.0, @:privateAccess aura.Aura.listener.velocity.length);

		panner.calculateDoppler();
		handle.channel.synchronize();

		// Values calculated at
		// https://www.omnicalculator.com/physics/doppler-effect?c=EUR&v=f0:5000!Hz,v:343.4!ms,vs:2!ms,vr:0!ms
		// Assuming that their implementation is correct
		Assert.floatEquals(4942.43 / 5000, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_physicallyCorrectValues_listenerMovesAway() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(2.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Assert.floatEquals(4.0, @:privateAccess aura.Aura.listener.velocity.length);
		Assert.floatEquals(0.0, @:privateAccess panner.velocity.length);

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(4941.76 / 5000, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_physicallyCorrectValues_pannerMovesCloser() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(4.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(2.0, 0.0, 0.0));

		Assert.floatEquals(4.0, @:privateAccess panner.velocity.length);
		Assert.floatEquals(0.0, @:privateAccess aura.Aura.listener.velocity.length);

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(5058.93 / 5000, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_physicallyCorrectValues_listenerMovesCloser() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(4.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(2.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		Assert.floatEquals(4.0, @:privateAccess aura.Aura.listener.velocity.length);
		Assert.floatEquals(0.0, @:privateAccess panner.velocity.length);

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(5058.24 / 5000, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_noDopplerEffectIfNoRadialVelocity() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(2.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 0.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(1, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_noDopplerEffectIfNoRadialVelocity2() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(5.0, 0.0, 0.0));
		panner.setLocation(new Vec3(5.0, 0.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(5.0, 0.0, 0.0));
		panner.setLocation(new Vec3(5.0, 0.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(1, handle.channel.pDopplerRatio.targetValue);
	}

	function test_calculateDoppler_noDopplerEffectIfNoRadialVelocity3() {
		Time.overrideTime = 0.0;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(2.0, 2.0, 0.0));

		Time.overrideTime = 0.5;
		aura.Aura.listener.setLocation(new Vec3(0.0, 0.0, 0.0));
		panner.setLocation(new Vec3(0.0, 2.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(1, handle.channel.pDopplerRatio.targetValue);
	}

	function test_dopplerEffect_isZeroIfPannerMovesCloserAtSpeedOfSound() {
		Time.overrideTime = 0.0;
		panner.setLocation(new Vec3(Panner.SPEED_OF_SOUND + 1, 0.0, 0.0));

		Time.overrideTime = 1.0;
		panner.setLocation(new Vec3(1, 0.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(0, handle.channel.pDopplerRatio.targetValue);
	}

	function test_dopplerEffect_pannerMovesCloserAboveSpeedOfSound() {
		Time.overrideTime = 0.0;
		panner.setLocation(new Vec3(Panner.SPEED_OF_SOUND + 5, 0.0, 0.0));

		Time.overrideTime = 1.0;
		panner.setLocation(new Vec3(1, 0.0, 0.0));

		panner.calculateDoppler();
		handle.channel.synchronize();

		Assert.floatEquals(-85.85, handle.channel.pDopplerRatio.targetValue);
	}
}
