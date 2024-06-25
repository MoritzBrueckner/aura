package aura;

import aura.math.Vec3;

@:allow(aura.Handle)
@:allow(aura.dsp.panner.Panner)
class Listener {
	public var location(default, null): Vec3;

	public var look(default, null): Vec3;
	public var right(default, null): Vec3;

	var velocity: Vec3;

	public function new() {
		this.location = new Vec3(0, 0, 0);
		this.velocity = new Vec3(0, 0, 0);

		this.look = new Vec3(0, 1, 0);
		this.right = new Vec3(1, 0, 0);
	}

	/**
		Set the listener's view direction. `look` points directly in the view
		direction, `right` is perpendicular to `look` and is used internally to
		get the sign of the angle between a channel and the listener.

		Both parameters must be normalized.
	**/
	public inline function setViewDirection(look: Vec3, right: Vec3) {
		assert(Debug, look.length == 1 && right.length == 1);

		this.look.setFrom(look);
		this.right.setFrom(right);
	}

	/**
		Set the location of this listener in world space.

		Calling this function also sets the listener's velocity if the call
		to this function is not the first call for this listener. This behavior
		avoids audible "jumps" in the audio output for initial placement
		of objects if they are far away from the origin.
	**/
	public function setLocation(location: Vec3) {
		final time = Time.getTime();
		final timeDeltaLastCall = time - _setLocation_lastCallTime;

		// If the last time setLocation() was called was at an earlier time step
		if (timeDeltaLastCall > 0) {
			_setLocation_lastLocation.setFrom(this.location);
			_setLocation_lastVelocityUpdateTime = _setLocation_lastCallTime;
		}

		final timeDeltaVelocityUpdate = time - _setLocation_lastVelocityUpdateTime;

		this.location.setFrom(location);

		if (!_setLocation_initializedLocation) {
			_setLocation_initializedLocation = true;
		}
		else if (timeDeltaVelocityUpdate > 0) {
			velocity.setFrom(location.sub(_setLocation_lastLocation).mult(1 / timeDeltaVelocityUpdate));
		}

		_setLocation_lastCallTime = time;
	}
	var _setLocation_initializedLocation = false;
	var _setLocation_lastLocation: Vec3 = new Vec3(0, 0, 0);
	var _setLocation_lastCallTime: Float = 0.0;
	var _setLocation_lastVelocityUpdateTime: Float = 0.0;

	/**
		Wrapper around `setViewDirection()` and `setLocation()`.
	**/
	public function set(location: Vec3, look: Vec3, right: Vec3) {
		inline setViewDirection(look, right);
		inline setLocation(location);
	}

	/**
		Resets the location, direction and velocity of the listener to their
		default values.
	**/
	public inline function reset() {
		this.location.setFrom(new Vec3(0, 0, 0));
		this.velocity.setFrom(new Vec3(0, 0, 0));

		this._setLocation_initializedLocation = false;
		this._setLocation_lastLocation.setFrom(new Vec3(0, 0, 0));
		this._setLocation_lastVelocityUpdateTime = Time.getTime();

		this.look.setFrom(new Vec3(0, 1, 0));
		this.right.setFrom(new Vec3(1, 0, 0));
	}
}
