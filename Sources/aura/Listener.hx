package aura;

import kha.math.FastVector3;

@:allow(aura.channels.AudioChannel)
class Listener {
	public var location: FastVector3;

	public var look(default, null): FastVector3;
	public var right(default, null): FastVector3;

	var lastLocation: FastVector3;
	var velocity: FastVector3;

	public function new() {
		this.location = new FastVector3(0, 0, 0);
		this.lastLocation = new FastVector3(0, 0, 0);
		this.velocity = new FastVector3(0, 0, 0);

		this.look = new FastVector3(0, 1, 0);
		this.right = new FastVector3(1, 0, 0);
	}

	/**
		Set the listener's view direction. `look` points directly in the view
		direction, `right` is `perpendicular` to `look` and is used internally
		to get the sign of the angle between a channel and the listener.

		Both parameters must be normalized.
	**/
	public function setViewDirection(look: FastVector3, right: FastVector3) {
		assert(Debug, look.length == 1 && right.length == 1);

		this.look = look;
		this.right = right;
	}
}
