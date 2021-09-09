package aura;

import kha.FastFloat;

import aura.channels.BaseChannel;
import aura.dsp.DSP;
import aura.math.Vec3;
import aura.utils.MathUtils;

/**
	Main-thread handle to an audio channel in the audio thread.
**/
@:access(aura.channels.BaseChannel)
@:access(aura.dsp.DSP)
class Handle {
	static inline var REFERENCE_DST = 1.0;
	static inline var SPEED_OF_SOUND = 343.4; // Air, m/s

	/**
		Link to the audio channel in the audio thread.
	**/
	final channel: BaseChannel;

	/**
		Whether the playback of the handle's channel is currently paused.
	**/
	public var paused(get, never): Bool;
	inline function get_paused(): Bool { return channel.paused; }

	/**
		Whether the playback of the handle's channel has finished.
		On `MixerChannel`s this value is always `false`.
	**/
	public var finished(get, never): Bool;
	inline function get_finished(): Bool { return channel.finished; }

	/**
		The location of this audio source in world space.
	**/
	public var location: Vec3 = new Vec3(0, 0, 0);

	/**
		The velocity of this audio source in world space.
	**/
	public var velocity: Vec3 = new Vec3(0, 0, 0);
	var lastLocation: Vec3 = new Vec3(0, 0, 0);

	public var dopplerFactor = 1.0;

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	// Parameter cache for getter functions
	var _volume: Float = 1.0;
	var _balance: Balance = Balance.CENTER;
	var _pitch: Float = 1.0;

	public inline function new(channel: BaseChannel) {
		this.channel = channel;
	}

	/**
		Starts the playback. If the sound wasn't played before or was stopped,
		the playback starts from the beginning. If it is paused, playback starts
		from the position where it was paused.
	**/
	public inline function play() {
		channel.sendMessage({ id: Play, data: null });
	}

	public inline function pause() {
		channel.sendMessage({ id: Pause, data: null });
	}

	public inline function stop() {
		channel.sendMessage({ id: Stop, data: null });
	}

	public inline function addInsert(insert: DSP): DSP {
		assert(Error, !insert.inUse, "DSP objects can only belong to one unique channel");
		insert.inUse = true;
		channel.inserts.push(insert);
		return insert;
	}

	public inline function removeInsert(insert: DSP) {
		var found = channel.inserts.remove(insert);
		if (found) {
			insert.inUse = false;
		}
	}

	/**
		Call this to update the channel's panning based on the location of this
		channel and the location and rotation of the current listener.
	**/
	public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = location.sub(listener.location);

		if (dirToChannel.length == 0) {
			setBalance(Balance.CENTER);
			channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
			return;
		}

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final up = listener.right.cross(listener.look).normalized();
		final projectedChannelPos = projectPointOntoPlane(dirToChannel, up).normalized();

		// Angle cosine
		var angle = getAngle(listener.look, projectedChannelPos);

		// The calculated angle cosine looks like this on the unit circle:
		//   /  1  \
		//  0   x   0   , where x is the listener and top is on the front
		//   \ -1  /

		// Make the center 0.5, use absolute angle to prevent phase flipping.
		// We loose front/back information here, but that's ok
		angle = Math.abs(angle * 0.5);

		// The angle cosine doesn't contain side information, so if the sound is
		// to the right of the listener, we must invert the angle
		if (getAngle(listener.right, projectedChannelPos) > 0) {
			angle = 1 - angle;
		}

		final dst = maxF(REFERENCE_DST, dirToChannel.length);
		final dstAttenuation = switch (attenuationMode) {
			case Linear:
				1 - attenuationFactor * (dst - REFERENCE_DST) / (maxDistance - REFERENCE_DST);
			case Inverse:
				REFERENCE_DST / (REFERENCE_DST + attenuationFactor * (dst - REFERENCE_DST));
			case Exponential:
				Math.pow(dst / REFERENCE_DST, -attenuationFactor);
		}

		var dopplerRatio: FastFloat = 1.0;
		if (dopplerFactor != 0.0 && (listener.velocity.length != 0 || this.velocity.length != 0)) {
			final dist = this.location.sub(listener.location);
			final vr = listener.velocity.dot(dist) / dist.length;
			final vs = this.velocity.dot(dist) / dist.length;

			final soundSpeed = SPEED_OF_SOUND * Time.delta;
			dopplerRatio = (soundSpeed + vr) / (soundSpeed + vs);
			dopplerRatio = Math.pow(dopplerRatio, dopplerFactor);
		}

		this.velocity = this.location.sub(this.lastLocation);
		this.lastLocation.setFrom(this.location);

		setBalance(angle);

		channel.sendMessage({ id: PDopplerRatio, data: dopplerRatio });
		channel.sendMessage({ id: PDstAttenuation, data: dstAttenuation });
	}

	public inline function setVolume(volume: Float) {
		channel.sendMessage({ id: PVolume, data: maxF(0.0, volume) });
		this._volume = volume;
	}

	public inline function getVolume(): Float {
		return this._volume;
	}

	public inline function setBalance(balance: Balance) {
		channel.sendMessage({ id: PBalance, data: balance });
		this._balance = balance;
	}

	public inline function getBalance(): Balance {
		return this._balance;
	}

	public inline function setPitch(pitch: Float) {
		channel.sendMessage({ id: PPitch, data: maxF(0.0, pitch) });
		this._pitch = pitch;
	}

	public inline function getPitch(): Float {
		return this._pitch;
	}
}
