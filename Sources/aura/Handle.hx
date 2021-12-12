package aura;

import kha.FastFloat;
import kha.arrays.Float32Array;
import kha.math.FastVector3;

import aura.channels.BaseChannel;
import aura.dsp.DelayLine;
import aura.dsp.DSP;
import aura.dsp.FFTConvolver;
import aura.math.Vec3;
import aura.utils.MathUtils;
import aura.utils.Pointer;

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
	var hrtfDelayLine: Null<DelayLine>;
	var hrirPtrDelay: Null<Pointer<Int>>;
	var hrirPtrImpulseLength: Null<Pointer<Int>>;
	var hrir: Null<Float32Array>;
	var hrirOpp: Null<Float32Array>;

	public inline function new(channel: BaseChannel) {
		this.channel = channel;

		if (Aura.options.panningMode == Hrtf) {
			hrtfConvolver = new FFTConvolver();
			hrtfDelayLine = new DelayLine(128); // TODO: move to a place when HRTFs are loaded
			hrtfConvolver.bypass = true;
			hrtfDelayLine.bypass = true;
			channel.addInsert(hrtfConvolver);
			channel.addInsert(hrtfDelayLine);

			hrirPtrDelay = new Pointer<Int>();
			hrirPtrImpulseLength = new Pointer<Int>();

			hrir = new Float32Array(FFTConvolver.CHUNK_SIZE);
			hrirOpp = new Float32Array(FFTConvolver.CHUNK_SIZE);
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
				case Balance:
					setBalance(Balance.CENTER);
				case Hrtf:
					hrtfConvolver.bypass = true;
					hrtfDelayLine.bypass = true;
			}
			channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final projectedChannelPos = projectPointOntoPlane(dirToChannel, up).normalized();

		switch (Aura.options.panningMode) {
			case Balance:

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
				final hrtf = @:privateAccess Aura.currentHRTF;

				final elevationCos = up.dot(dirToChannel.normalized());
				// 180: top, 0: bottom
				final elevation = 180 - (Math.acos(elevationCos) * (180 / Math.PI));

				var angle = getFullAngleDegrees(look, projectedChannelPos, up);
				angle = angle != 0 ? 360 - angle : 0; // Make clockwise

				hrtf.getInterpolatedHRIR(elevation, angle, hrir, hrirPtrImpulseLength, hrirPtrDelay);
				final hrirLength = hrirPtrImpulseLength.get();
				final hrirDelay = hrirPtrDelay.get();

				if (hrtf.numChannels == 1) {
					hrtf.getInterpolatedHRIR(elevation, 360 - angle, hrirOpp, hrirPtrImpulseLength, hrirPtrDelay);
					final hrirOppLength = hrirPtrImpulseLength.get();
					final hrirOppDelay = hrirPtrDelay.get();

					final swapBuf = hrtfConvolver.impulseSwapBuffer;
					swapBuf.beginWrite();
						// Left channel
						swapBuf.writeF32Array(hrir, 0, 0, hrirLength);
						swapBuf.writeZero(hrirLength, FFTConvolver.CHUNK_SIZE);

						// Right channel
						swapBuf.writeF32Array(hrirOpp, 0, FFTConvolver.CHUNK_SIZE, hrirOppLength);
						swapBuf.writeZero(FFTConvolver.CHUNK_SIZE + hrirOppLength, swapBuf.length);
					swapBuf.endWrite();

					hrtfConvolver.bypass = false;
					hrtfDelayLine.bypass = false;
					hrtfConvolver.sendMessage({id: SwapBufferReady, data: [hrirLength, hrirOppLength]});
					hrtfDelayLine.sendMessage({id: SetDelays, data: [hrirDelay, hrirOppDelay]});
				}
				else {
					for (c in 0...hrtf.numChannels) {
						// final delaySamples = Math.round(hrir.delays[0]);

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
		switch (Aura.options.panningMode) {
			case Balance:
				setBalance(Balance.CENTER);
			case Hrtf:
				hrtfConvolver.bypass = true;
				hrtfDelayLine.bypass = true;
		}

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
