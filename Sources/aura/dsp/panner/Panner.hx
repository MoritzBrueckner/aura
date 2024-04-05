package aura.dsp.panner;

import kha.FastFloat;
import kha.math.FastVector3;

import aura.channels.BaseChannel.BaseChannelHandle;
import aura.math.Vec3;
import aura.threading.Message;
import aura.utils.MathUtils;

abstract class Panner extends DSP {
	static inline var REFERENCE_DST = 1.0;
	static inline var SPEED_OF_SOUND = 343.4; // Air, m/s

	public var dopplerFactor = 1.0;

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	var handle: BaseChannelHandle;

	/**
		The location of this audio source in world space.
	**/
	var location: Vec3 = new Vec3(0, 0, 0);
	var lastLocation: Vec3 = new Vec3(0, 0, 0);
	var lastLocationUpdateTime: Float = 0.0;
	var initializedLocation = false;

	/**
		The velocity of this audio source in world space.
	**/
	var velocity: Vec3 = new Vec3(0, 0, 0);

	public function new(handle: BaseChannelHandle) {
		this.inUse = true; // Don't allow using panners with addInsert()
		this.handle = handle;
		this.handle.channel.panner = this;
	}

	public inline function setHandle(handle: BaseChannelHandle) {
		if (this.handle != null) {
			this.handle.channel.panner = null;
		}
		reset3D();
		this.handle = handle;
		this.handle.channel.panner = this;
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
		handle.channel.sendMessage({ id: ChannelMessageID.PDopplerRatio, data: 1.0 });
		handle.channel.sendMessage({ id: ChannelMessageID.PDstAttenuation, data: 1.0 });
	};

	/**
		Set the location of this panner in world space.
	**/
	public function setLocation(location: Vec3) {
		final time = Time.getTime();

		this.lastLocation.setFrom(this.location);

		if (!initializedLocation) {
			// Prevent jumps in the doppler effect caused by initial distance
			// too far away from the origin
			initializedLocation = true;
		} else {
			final timeDelta = time - lastLocationUpdateTime;
			this.velocity.setFrom(location.sub(this.lastLocation).mult(1 / timeDelta));
		}

		this.location.setFrom(location);
		this.lastLocationUpdateTime = time;
	}

	function calculateAttenuation(dirToChannel: FastVector3) {
		final dst = maxF(REFERENCE_DST, dirToChannel.length);
		final dstAttenuation = switch (attenuationMode) {
			case Linear:
				maxF(0.0, 1 - attenuationFactor * (dst - REFERENCE_DST) / (maxDistance - REFERENCE_DST));
			case Inverse:
				REFERENCE_DST / (REFERENCE_DST + attenuationFactor * (dst - REFERENCE_DST));
			case Exponential:
				Math.pow(dst / REFERENCE_DST, -attenuationFactor);
		}
		handle.channel.sendMessage({ id: ChannelMessageID.PDstAttenuation, data: dstAttenuation });
	}

	function calculateDoppler() {
		final listener = Aura.listener;

		var dopplerRatio: FastFloat = 1.0;
		if (dopplerFactor != 0.0 && (listener.velocity.length != 0 || this.velocity.length != 0)) {
			final displacementToSource = this.location.sub(listener.location);
			final dist = displacementToSource.length;

			if (dist == 0) {
				// We don't have any radial velocity here...
				handle.channel.sendMessage({ id: ChannelMessageID.PDopplerRatio, data: 1.0 });
				return;
			}

			// Calculate radial velocity
			final vr = listener.velocity.dot(displacementToSource) / dist;
			final vs = this.velocity.dot(displacementToSource) / dist;

			// Sound source comes closer exactly at speed of sound,
			// make silent and prevent division by zero below
			if (vs == -SPEED_OF_SOUND) {
				handle.channel.sendMessage({ id: ChannelMessageID.PDopplerRatio, data: 0.0 });
				return;
			}

			dopplerRatio = (SPEED_OF_SOUND + vr) / (SPEED_OF_SOUND + vs);
			dopplerRatio = Math.pow(dopplerRatio, dopplerFactor);
		}

		if (dopplerRatio != null) {
			if (dopplerRatio >= 0.0) {
				handle.channel.sendMessage({ id: ChannelMessageID.PDopplerRatio, data: dopplerRatio });
			}
		}
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
