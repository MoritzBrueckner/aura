package aura.channels;

import kha.math.FastVector3;
import kha.arrays.Float32Array;

import aura.utils.MathUtils;

/**
	Base class of all audio channels.
**/
abstract class AudioChannel {
	static inline var REFERENCE_DST = 1.0;

	/**
		The sound's volume relative to the volume of the sound file.
	**/
	public var volume: Float = 1.0;
	public var balance = Balance.CENTER;

	public var location: FastVector3 = new FastVector3(0, 0, 0);

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	var treeLevel: Int = 0;

	var paused: Bool = false;
	var dstAttenuation: Float = 1.0;

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
			this.dstAttenuation = 1.0;
			return;
		}

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

		var dst = maxF(REFERENCE_DST, dirToChannel.length);
		this.dstAttenuation = switch (attenuationMode) {
			case Linear:
				1 - attenuationFactor * (dst - REFERENCE_DST) / (maxDistance - REFERENCE_DST);
			case Inverse:
				REFERENCE_DST / (REFERENCE_DST + attenuationFactor * (dst - REFERENCE_DST));
			case Exponential:
				Math.pow(dst / REFERENCE_DST, -attenuationFactor);
		}
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
