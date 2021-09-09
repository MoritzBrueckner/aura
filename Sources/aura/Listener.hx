package aura;

import aura.math.Vec3;

@:allow(aura.Handle)
class Listener {
	public var location(default, null): Vec3;

	public var look(default, null): Vec3;
	public var right(default, null): Vec3;

	var lastLocation: Vec3;
	var velocity: Vec3;

	public function new() {
		this.location = new Vec3(0, 0, 0);
		this.lastLocation = new Vec3(0, 0, 0);
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

		this.look = look;
		this.right = right;
	}

	/**
		Set the listener's location (and its velocity based on that).
	**/
	public inline function setLocation(location: Vec3) {
		this.velocity = this.location.sub(this.lastLocation);
		this.lastLocation.setFrom(this.location);
		this.location = location;
	}

	/**
		Wrapper around `setViewDirection()` and `setLocation()`.
	**/
	public inline function update(location: Vec3, look: Vec3, right: Vec3) {
		inline setViewDirection(look, right);
		inline setLocation(location);
	}
}
