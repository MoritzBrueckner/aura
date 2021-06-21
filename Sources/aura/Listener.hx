package aura;

import kha.math.FastVector3;

class Listener {
	public var position(default, null): FastVector3;
	public var rotation(default, null): FastVector3;

	public function new() {
		this.position = new FastVector3(0, 0, 0);
		this.rotation = new FastVector3(0, 0, 0);
	}

	public inline function setPosition(position: FastVector3) {
		this.position = position;
	}

	public inline function setRotation(rightVector: FastVector3) {
		this.rotation = rightVector;
	}
}
