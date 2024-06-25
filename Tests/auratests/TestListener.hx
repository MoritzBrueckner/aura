package auratests;

import utest.Assert;

import aura.Aura;
import aura.Time;
import aura.Listener;
import aura.math.Vec3;

import Utils;

@:access(aura.Listener)
class TestListener extends utest.Test {
	var listener: Listener;

	function setup() {
		listener = new Listener();
	}

	function teardown() {
		Time.overrideTime = null;
	}

	function test_setLocation_multipleCallsOnFirstTimestep() {
		Time.overrideTime = 0.0;
		listener.setLocation(new Vec3(0.5, 0.6, 0.7));

		Assert.floatEquals(0.5, listener.location.x);
		Assert.floatEquals(0.6, listener.location.y);
		Assert.floatEquals(0.7, listener.location.z);

		Assert.floatEquals(0.0, listener.velocity.x);
		Assert.floatEquals(0.0, listener.velocity.y);
		Assert.floatEquals(0.0, listener.velocity.z);

		Time.overrideTime = 0.0;
		listener.setLocation(new Vec3(1.0, 2.0, 3.0));

		Assert.floatEquals(1.0, listener.location.x);
		Assert.floatEquals(2.0, listener.location.y);
		Assert.floatEquals(3.0, listener.location.z);

		Assert.floatEquals(0.0, listener.velocity.x);
		Assert.floatEquals(0.0, listener.velocity.y);
		Assert.floatEquals(0.0, listener.velocity.z);
	}

	function test_setLocation_firstCall_timeDeltaZero() {
		Time.overrideTime = 0.0;
		listener.setLocation(new Vec3(0.5, 0.6, 0.7));

		Assert.floatEquals(0.5, listener.location.x);
		Assert.floatEquals(0.6, listener.location.y);
		Assert.floatEquals(0.7, listener.location.z);

		Assert.floatEquals(0.0, listener.velocity.x);
		Assert.floatEquals(0.0, listener.velocity.y);
		Assert.floatEquals(0.0, listener.velocity.z);
	}

	function test_setLocation_firstCall_timeDeltaPositive() {
		Time.overrideTime = 2.0;
		listener.setLocation(new Vec3(0.5, 0.6, 0.7));

		Assert.floatEquals(0.5, listener.location.x);
		Assert.floatEquals(0.6, listener.location.y);
		Assert.floatEquals(0.7, listener.location.z);

		Assert.floatEquals(0.0, listener.velocity.x);
		Assert.floatEquals(0.0, listener.velocity.y);
		Assert.floatEquals(0.0, listener.velocity.z);
	}

	function test_setLocation_subsequentCalls_timeDeltaZero() {
		// Regression test for https://github.com/MoritzBrueckner/aura/pull/8

		Time.overrideTime = 1.0;
		listener.setLocation(new Vec3(0.0, 0.0, 0.0));

		Time.overrideTime = 3.0;
		listener.setLocation(new Vec3(1.0, 2.0, 3.0));

		Time.overrideTime = 3.0;
		listener.setLocation(new Vec3(2.0, 4.0, 6.0));

		Assert.floatEquals(2.0, listener.location.x);
		Assert.floatEquals(4.0, listener.location.y);
		Assert.floatEquals(6.0, listener.location.z);

		// Compute velocity based on timestep 1.0
		Assert.floatEquals(1.0, listener.velocity.x);
		Assert.floatEquals(2.0, listener.velocity.y);
		Assert.floatEquals(3.0, listener.velocity.z);
	}
}
