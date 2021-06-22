package aura;

import kha.math.FastVector3;
import kha.arrays.Float32Array;

import aura.MathUtils;

abstract class AudioChannel {
	/**
		The sound's volume relative to the volume of the sound file.
	**/
	public var volume: Float = 1.0;
	public var balance = Balance.CENTER;

	public var location: FastVector3 = new FastVector3(0, 0, 0);

	var treeLevel: Int = 0;

	var paused: Bool = false;

	public abstract function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;

	/**
		Call this to update the channel's panning based on the location of this
		channel and the location and rotation of the current listener.
	**/
	public function update3D() {
		var dirToChannel = location.sub(Aura.listener.location);

		if (dirToChannel.length == 0) {
			this.balance = Balance.CENTER;
			return;
		}

		var distance = dirToChannel.length / 4; // TODO Falloff distance
		var dstVolume = Math.max(0, 4 - distance) / 4 * volume;


		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		var up = Aura.listener.right.cross(Aura.listener.look).normalized();
		var projectedChannelPos = projectPointOntoPlane(dirToChannel, up);

		projectedChannelPos = projectedChannelPos.normalized();
		var angle = getAngle(Aura.listener.look, projectedChannelPos);

		angle *= 0.5;

		// The sound is right to the listener, we need this to account for the
		// missing "side information" in the angle cosine
		if (getAngle(Aura.listener.right, projectedChannelPos) > 0) {
			angle = 1 - angle;
		}

		this.balance = angle;

		// volume *= dstVolume;
	}
}
