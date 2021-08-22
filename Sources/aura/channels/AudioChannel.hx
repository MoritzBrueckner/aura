package aura.channels;

import kha.arrays.Float32Array;

import aura.math.Vec3;
import aura.utils.MathUtils;

/**
	Base class of all audio channels.
**/
abstract class AudioChannel {
	static inline var REFERENCE_DST = 1.0;
	static inline var SPEED_OF_SOUND = 343.4; // Air, m/s

	/**
		The sound's volume relative to the volume of the sound file.
	**/
	public var volume: Float = 1.0;
	public var balance = Balance.CENTER;

	public var location: Vec3 = new Vec3(0, 0, 0);
	var lastLocation: Vec3 = new Vec3(0, 0, 0);
	public var velocity: Vec3 = new Vec3(0, 0, 0);

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	public var dopplerFactor = 1.0;

	var treeLevel: Int = 0;

	var paused: Bool = false;
	var dstAttenuation: Float = 1.0;
	var dopplerRatio: Float = 1.0;

	public abstract function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;

	/**
		Call this to update the channel's panning based on the location of this
		channel and the location and rotation of the current listener.
	**/
	public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = location.sub(listener.location);

		if (dirToChannel.length == 0) {
			this.balance = Balance.CENTER;
			this.dstAttenuation = 1.0;
			return;
		}

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final up = listener.right.cross(listener.look).normalized();
		var projectedChannelPos = projectPointOntoPlane(dirToChannel, up);

		projectedChannelPos = projectedChannelPos.normalized();
		var angle = getAngle(listener.look, projectedChannelPos);

		angle *= 0.5;

		// The sound is right to the listener, we need this to account for the
		// missing "side information" in the angle cosine
		if (getAngle(listener.right, projectedChannelPos) > 0) {
			angle = 1 - angle;
		}

		this.balance = angle;

		final dst = maxF(REFERENCE_DST, dirToChannel.length);
		this.dstAttenuation = switch (attenuationMode) {
			case Linear:
				1 - attenuationFactor * (dst - REFERENCE_DST) / (maxDistance - REFERENCE_DST);
			case Inverse:
				REFERENCE_DST / (REFERENCE_DST + attenuationFactor * (dst - REFERENCE_DST));
			case Exponential:
				Math.pow(dst / REFERENCE_DST, -attenuationFactor);
		}

		if (dopplerFactor == 0.0 || (listener.velocity.length == 0 && this.velocity.length == 0)) {
			dopplerRatio = 1.0;
		}
		else {
			final dist = this.location.sub(listener.location);
			final vr = listener.velocity.dot(dist) / dist.length;
			final vs = this.velocity.dot(dist) / dist.length;

			final soundSpeed = SPEED_OF_SOUND * Time.delta;
			dopplerRatio = (soundSpeed + vr) / (soundSpeed + vs);
			dopplerRatio = Math.pow(dopplerRatio, dopplerFactor);
		}

		listener.velocity = listener.location.sub(listener.lastLocation);
		listener.lastLocation.setFrom(listener.location);

		this.velocity = this.location.sub(this.lastLocation);
		this.lastLocation.setFrom(this.location);
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
