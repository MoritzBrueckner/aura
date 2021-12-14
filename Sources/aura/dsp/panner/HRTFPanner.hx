package aura.dsp.panner;

import kha.arrays.Float32Array;

import aura.utils.Pointer;
import aura.utils.MathUtils;

class HRTFPanner extends Panner {
	final hrtfConvolver: FFTConvolver;
	final hrtfDelayLine: DelayLine;
	final hrirPtrDelay: Pointer<Int>;
	final hrirPtrImpulseLength: Pointer<Int>;
	final hrir: Float32Array;
	final hrirOpp: Float32Array;

	public function new(handle: Handle) {
		super(handle);

		hrtfConvolver = new FFTConvolver();
		hrtfDelayLine = new DelayLine(128); // TODO: move to a place when HRTFs are loaded
		hrtfConvolver.bypass = true;
		hrtfDelayLine.bypass = true;
		handle.channel.addInsert(hrtfConvolver);
		handle.channel.addInsert(hrtfDelayLine);

		hrirPtrDelay = new Pointer<Int>();
		hrirPtrImpulseLength = new Pointer<Int>();

		hrir = new Float32Array(FFTConvolver.CHUNK_SIZE);
		hrirOpp = new Float32Array(FFTConvolver.CHUNK_SIZE);
	}

	override public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = this.location.sub(listener.location);

		if (dirToChannel.length == 0) {
			hrtfConvolver.bypass = true;
			hrtfDelayLine.bypass = true;
			handle.channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final projectedChannelPos = projectPointOntoPlane(dirToChannel, up).normalized();

		final hrtf = @:privateAccess Aura.currentHRTF;

		final elevationCos = up.dot(dirToChannel.normalized());
		// 180: top, 0: bottom
		final elevation = 180 - (Math.acos(elevationCos) * (180 / Math.PI));

		var angle = getFullAngleDegrees(look, projectedChannelPos, up);
		angle = angle != 0 ? 360 - angle : 0; // Make clockwise

		hrtf.getInterpolatedHRIR(elevation, angle, hrir, hrirPtrImpulseLength, hrirPtrDelay);
		final hrirLength = hrirPtrImpulseLength.getSure();
		final hrirDelay = hrirPtrDelay.getSure();

		if (hrtf.numChannels == 1) {
			hrtf.getInterpolatedHRIR(elevation, 360 - angle, hrirOpp, hrirPtrImpulseLength, hrirPtrDelay);
			final hrirOppLength = hrirPtrImpulseLength.getSure();
			final hrirOppDelay = hrirPtrDelay.getSure();

			final swapBuf = @:privateAccess hrtfConvolver.impulseSwapBuffer;
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

		super.update3D();
	}

	override public function reset3D() {
		hrtfConvolver.bypass = true;
		hrtfDelayLine.bypass = true;

		super.reset3D();
	}
}
