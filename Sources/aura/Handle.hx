package aura;

import kha.FastFloat;
import kha.math.FastVector3;

import aura.channels.BaseChannel;
import aura.dsp.DSP;
import aura.dsp.FFTConvolver;
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

	public var dopplerFactor = 1.0;

	public var attenuationMode = AttenuationMode.Inverse;
	public var attenuationFactor = 1.0;
	public var maxDistance = 10.0;
	// public var minDistance = 1;

	/**
		The location of this audio source in world space.
	**/
	var location: Vec3 = new Vec3(0, 0, 0);
	var lastLocation: Vec3 = new Vec3(0, 0, 0);

	/**
		The velocity of this audio source in world space.
	**/
	var velocity: Vec3 = new Vec3(0, 0, 0);

	// Parameter cache for getter functions
	var _volume: Float = 1.0;
	var _balance: Balance = Balance.CENTER;
	var _pitch: Float = 1.0;

	var hrtfConvolver: Null<FFTConvolver>;

	public inline function new(channel: BaseChannel) {
		this.channel = channel;

		if (Aura.options.panningMode == Hrtf) {
			hrtfConvolver = new FFTConvolver();
			channel.addInsert(hrtfConvolver);
		}
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
		return channel.addInsert(insert);
	}

	public inline function removeInsert(insert: DSP) {
		channel.removeInsert(insert);
	}

	/**
		Call this to update the channel's audible 3D parameters.
	**/
	public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = location.sub(listener.location);

		if (dirToChannel.length == 0) {
			switch (Aura.options.panningMode) {
				case Balance: setBalance(Balance.CENTER);
				case Hrtf: // TODO: bypass HRTF, else disable bypass
			}
			channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

		switch (Aura.options.panningMode) {
			case Balance:
				// Project the channel position (relative to the listener) to the plane
				// described by the listener's look and right vectors
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
				setBalance(angle);

			case Hrtf:
				final hrtf = @:privateAccess Aura.hrtfs[Aura.currentHRTF];

				// TODO Use fixed distance for now...
				final field = hrtf.fields[0];

				final elevationCos = up.dot(dirToChannel.normalized());
				// 180: top, 0: bottom
				final elevation = 180 - (Math.acos(elevationCos) * (180 / Math.PI));
				final elevationStep = 180 / field.evCount;
				final elevationIndex = getNearestIndexF(elevation, elevationStep);

				// Calculate the offset into the HRIR array, different
				// elevations may have different amounts of azimuths/HRIRs
				// TODO: store offset per elevation for faster access?
				var elevationHRIROffset = 0;
				for (j in 0...elevationIndex) {
					elevationHRIROffset += field.azCount[j];
				}

				var angle = getFullAngleDegrees(look, dirToChannel);
				angle = angle != 0 ? 360 - angle : 0; // Make clockwise

				// TODO: azCount can be 0, leading to NaN errors...
				final azimuthStep = 360 / field.azCount[elevationIndex];
				final azimuthIndex = getNearestIndexF(angle, azimuthStep);


				// TODO: Interpolation

				final hrir = field.hrirs[elevationHRIROffset + azimuthIndex];

				if (hrtf.numChannels == 1) {
					final opposizeAzimuthIndex = field.azCount[elevationIndex] - azimuthIndex;
					final hrirOpposite = field.hrirs[elevationHRIROffset + opposizeAzimuthIndex];

					final delaySamples = Math.round(hrir.delays[0]);
					final delaySamplesOpp = Math.round(hrirOpposite.delays[0]);

					final coeffsLength = hrtf.hrirSize;
					final impulseLength = coeffsLength + delaySamples;

					final swapBuf = hrtfConvolver.impulseSwapBuffer;

					// Left channel
					swapBuf.writeZero(0, delaySamples);
					swapBuf.writeVecF(hrir.coeffs, 0, delaySamples, coeffsLength);
					swapBuf.writeZero(impulseLength, FFTConvolver.CHUNK_SIZE);

					// Right channel
					swapBuf.writeZero(FFTConvolver.CHUNK_SIZE, FFTConvolver.CHUNK_SIZE + delaySamples);
					swapBuf.writeVecF(hrirOpposite.coeffs, 0, FFTConvolver.CHUNK_SIZE + delaySamples, coeffsLength);
					swapBuf.writeZero(FFTConvolver.CHUNK_SIZE + impulseLength, swapBuf.length);

					swapBuf.swap();
					hrtfConvolver.sendMessage({id: SwapBufferReady, data: [impulseLength, 2]});
				}
				else {
					for (c in 0...hrtf.numChannels) {
						final delaySamples = Math.round(hrir.delays[0]);

						// TODO: handle interleaved coeffs of stereo HRTFs
						// Deinterleave when reading the file?
					}
				}
		}

		calculateAttenuation(dirToChannel);
		calculateDoppler();
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
		channel.sendMessage({ id: PDstAttenuation, data: dstAttenuation });
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

		this.velocity = this.location.sub(this.lastLocation);
		this.lastLocation.setFrom(this.location);

		channel.sendMessage({ id: PDopplerRatio, data: dopplerRatio });
	}

	/**
		Reset all the audible 3D sound parameters (balance, doppler effect etc.)
		which are calculated by `update3D()`. This function does *not* reset the
		location value of the sound, so if you call `update3D()` again, you will
		hear the sound at the same position as before you called `reset3D()`.
	**/
	public inline function reset3D() {
		setBalance(Balance.CENTER);

		channel.sendMessage({ id: PDopplerRatio, data: 1.0 });
		channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
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

	/**
		Set the location of this audio source in world space.
	**/
	public inline function setLocation(location: Vec3) {
		this.location = location;
	}

	#if AURA_DEBUG
	public function getDebugAttrs(): Map<String, String> {
		return ["In use" => Std.string(@:privateAccess channel.isPlayable())];
	}
	#end
}
