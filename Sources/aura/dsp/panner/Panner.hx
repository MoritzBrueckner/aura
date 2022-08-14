package aura.dsp.panner;

import kha.FastFloat;
import kha.math.FastVector3;

import aura.math.Vec3;
import aura.utils.MathUtils;

abstract class Panner {
	static inline var REFERENCE_DST = 1.0;
	static inline var SPEED_OF_SOUND = 343.4; // Air, m/s

	public var dopplerFactor = 1.0;

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	var handle: Handle;

	/**
		The location of this audio source in world space.
	**/
	var location: Vec3 = new Vec3(0, 0, 0);
	var lastLocation: Vec3 = new Vec3(0, 0, 0);
	var initializedLocation = false;

	/**
		The velocity of this audio source in world space.
	**/
	var velocity: Vec3 = new Vec3(0, 0, 0);

	public inline function new(handle: Handle) {
		this.handle = handle;
		this.handle.panner = this;
	}

	public inline function setHandle(handle: Handle) {
		if (this.handle != null) {
			this.handle.panner = null;
		}
		reset3D();
		this.handle = handle;
		this.handle.panner = this;
	}

	/**
		Update the channel's audible 3D parameters after changing the channel's
		or the listener's position or rotation.
	**/
	public function update3D() {
		final dirToChannel = this.location.sub(Aura.listener.location);
		calculateAttenuation(dirToChannel);
		calculateDoppler();
	};

	/**
		Reset all the audible 3D sound parameters (balance, doppler effect etc.)
		which are calculated by `update3D()`. This function does *not* reset the
		location value of the sound, so if you call `update3D()` again, you will
		hear the sound at the same position as before you called `reset3D()`.
	**/
	public function reset3D() {
		handle.channel.sendMessage({ id: PDopplerRatio, data: 1.0 });
		handle.channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
	};

	/**
		Set the location of this panner in world space.
	**/
	public inline function setLocation(location: Vec3) {
		this.lastLocation.setFrom(this.location);
		this.location = location;

		if (!initializedLocation) {
			initializedLocation = true;
		} else {
			// Prevent jumps in the doppler effect caused by initial distance
			// too far away from the origin
			this.velocity = this.location.sub(this.lastLocation);
		}
	}

	function calculateAttenuation(dirToChannel: FastVector3) {
		final dst = maxF(REFERENCE_DST, dirToChannel.length);
		final dstAttenuation = switch (attenuationMode) {
			case Linear:
				1 - attenuationFactor * (dst - REFERENCE_DST) / (maxDistance - REFERENCE_DST);
			case Inverse:
				REFERENCE_DST / (REFERENCE_DST + attenuationFactor * (dst - REFERENCE_DST));
			case Exponential:
				Math.pow(dst / REFERENCE_DST, -attenuationFactor);
		}
		handle.channel.sendMessage({ id: PDstAttenuation, data: dstAttenuation });
	}

	function calculateDoppler() {
		final listener = Aura.listener;
		var dopplerRatio: FastFloat = 1.0;
		if (dopplerFactor != 0.0 && (listener.velocity.length != 0 || this.velocity.length != 0)) {
			final dist = this.location.sub(listener.location);
			final vr = listener.velocity.dot(dist) / dist.length;
			final vs = this.velocity.dot(dist) / dist.length;

			final soundSpeed = SPEED_OF_SOUND * Time.delta;
			dopplerRatio = (soundSpeed + vr) / (soundSpeed + vs);
			dopplerRatio = Math.pow(dopplerRatio, dopplerFactor);
		}

		handle.channel.sendMessage({ id: PDopplerRatio, data: dopplerRatio });
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
