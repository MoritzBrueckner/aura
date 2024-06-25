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

	/**
		The strength of the doppler effect.

		This value is multiplied to the calculated doppler effect, thus:
		- A value of `0.0` results in no doppler effect.
		- A value between `0.0` and `1.0` attenuates the effect (smaller values: more attenuation).
		- A value of `1.0` does not attenuate or amplify the doppler effect.
		- A value larger than `1.0` amplifies the doppler effect (larger values: more amplification).
	**/
	public var dopplerStrength = 1.0;

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	var handle: BaseChannelHandle;

	/**
		The location of this audio source in world space.
	**/
	var location: Vec3 = new Vec3(0, 0, 0);

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
		final displacementToSource = location.sub(Aura.listener.location);
		calculateAttenuation(displacementToSource);
		calculateDoppler(displacementToSource);
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

		Calling this function also sets the panner's velocity if the call
		to this function is not the first call for this panner. This behavior
		avoids audible "jumps" in the doppler effect for initial placement
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
			// Prevent jumps in the doppler effect caused by initial distance
			// too far away from the origin
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

	function calculateDoppler(displacementToSource: FastVector3) {
		final listener = Aura.listener;

		var dopplerRatio: FastFloat = 1.0;
		if (dopplerStrength != 0.0 && (listener.velocity.length != 0 || this.velocity.length != 0)) {

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
			dopplerRatio = Math.pow(dopplerRatio, dopplerStrength);
		}

		handle.channel.sendMessage({ id: ChannelMessageID.PDopplerRatio, data: dopplerRatio });
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
