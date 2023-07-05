package aura.dsp.panner;

import kha.FastFloat;
import kha.arrays.Float32Array;

import aura.Types.Channels;
import aura.channels.BaseChannel.BaseChannelHandle;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.types.HRTF;
import aura.utils.MathUtils;
import aura.utils.Pointer;

class HRTFPanner extends Panner {
	public var hrtf: HRTF;

	final hrtfConvolver: FFTConvolver;
	final hrtfDelayLine: FractionalDelayLine;
	final hrirPtrDelay: Pointer<FastFloat>;
	final hrirPtrImpulseLength: Pointer<Int>;
	final hrir: Float32Array;
	final hrirOpp: Float32Array;

	public function new(handle: BaseChannelHandle, hrtf: HRTF) {
		super(handle);

		this.hrtf = hrtf;

		hrtfConvolver = new FFTConvolver();
		hrtfDelayLine = new FractionalDelayLine(2, Math.ceil(hrtf.maxDelayLength));
		hrtfConvolver.bypass = true;
		hrtfDelayLine.bypass = true;

		hrirPtrDelay = new Pointer<FastFloat>();
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
			handle.channel.sendMessage({ id: ChannelMessageID.PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final projectedChannelPos = projectPointOntoPlane(dirToChannel, up).normalized();

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
				swapBuf.write(hrir, 0, 0, hrirLength);
				swapBuf.writeZero(hrirLength, FFTConvolver.CHUNK_SIZE);

				// Right channel
				swapBuf.write(hrirOpp, 0, FFTConvolver.CHUNK_SIZE, hrirOppLength);
				swapBuf.writeZero(FFTConvolver.CHUNK_SIZE + hrirOppLength, swapBuf.length);
			swapBuf.endWrite();

			hrtfConvolver.bypass = false;
			hrtfDelayLine.bypass = false;
			hrtfConvolver.sendMessage({id: DSPMessageID.SwapBufferReady, data: [hrirLength, hrirOppLength]});
			hrtfDelayLine.setDelayLength(Channels.Left, hrirDelay);
			hrtfDelayLine.setDelayLength(Channels.Right, hrirOppDelay);
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

	function process(buffer: AudioBuffer) {
		if (!hrtfConvolver.bypass) {
			hrtfConvolver.synchronize();
			hrtfConvolver.process(buffer);

			hrtfDelayLine.synchronize();
			hrtfDelayLine.process(buffer);
		}
	}
}
