package aura.dsp.panner;

import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.Interpolator.LinearInterpolator;
import aura.utils.MathUtils;

using aura.utils.StepIterator;

class StereoPanner extends Panner {
	final pVolumeLeft = new LinearInterpolator(1.0);
	final pVolumeRight = new LinearInterpolator(1.0);

	var _balance = Balance.CENTER;

	override public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = this.location.sub(listener.location);

		if (dirToChannel.length == 0) {
			setBalance(Balance.CENTER);
			handle.channel.sendMessage({ id: ChannelMessageID.PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

		// Project the channel position (relative to the listener) to the plane
		// described by the listener's look and right vectors
		final projectedChannelPos = projectPointOntoPlane(dirToChannel, up).normalized();

		// Angle cosine
		var angle = listener.look.dot(projectedChannelPos);

		// The calculated angle cosine looks like this on the unit circle:
		//   /  1  \
		//  0   x   0   , where x is the listener and top is on the front
		//   \ -1  /

		// Make the center 0.5, use absolute angle to prevent phase flipping.
		// We loose front/back information here, but that's ok
		angle = Math.abs(angle * 0.5);

		// The angle cosine doesn't contain side information, so if the sound is
		// to the right of the listener, we must invert the angle
		if (listener.right.dot(projectedChannelPos) > 0) {
			angle = 1 - angle;
		}

		setBalance(angle);

		super.update3D();
	}

	override public function reset3D() {
		setBalance(Balance.CENTER);

		super.reset3D();
	}

	public inline function setBalance(balance: Balance) {
		this._balance = balance;

		sendMessage({ id: StereoPannerMessageID.PVolumeLeft, data: Math.sqrt(~balance) });
		sendMessage({ id: StereoPannerMessageID.PVolumeRight, data: Math.sqrt(balance) });
	}

	public inline function getBalance(): Balance {
		return this._balance;
	}

	function process(buffer: AudioBuffer) {
		assert(Critical, buffer.numChannels == 2, "A StereoPanner can only be applied to stereo channels");

		final channelViewL = buffer.getChannelView(0);
		final channelViewR = buffer.getChannelView(1);

		final stepSizeL = pVolumeLeft.getLerpStepSize(buffer.channelLength);
		final stepSizeR = pVolumeRight.getLerpStepSize(buffer.channelLength);

		#if AURA_SIMD
			final stepSizesL = pVolumeLeft.getLerpStepSizes32x4(buffer.channelLength);
			final stepSizesR = pVolumeRight.getLerpStepSizes32x4(buffer.channelLength);

			final lenRemainder = mod4(buffer.channelLength);
			final startRemainder = buffer.channelLength - lenRemainder - 1;

			for (i in (0...buffer.channelLength).step(4)) {
				pVolumeLeft.applySIMD32x4(channelViewL, i, stepSizesL);
				pVolumeRight.applySIMD32x4(channelViewR, i, stepSizesR);
			}

			for (i in startRemainder...lenRemainder) {
				channelViewL[i] *= pVolumeLeft.currentValue;
				channelViewR[i] *= pVolumeRight.currentValue;
				pVolumeLeft.currentValue += stepSizeL;
				pVolumeRight.currentValue += stepSizeR;
			}
		#else
			for (i in 0...buffer.channelLength) {
				channelViewL[i] *= pVolumeLeft.currentValue;
				channelViewR[i] *= pVolumeRight.currentValue;
				pVolumeLeft.currentValue += stepSizeL;
				pVolumeRight.currentValue += stepSizeR;
			}
		#end

		pVolumeLeft.updateLast();
		pVolumeRight.updateLast();
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			case StereoPannerMessageID.PVolumeLeft: pVolumeLeft.targetValue = cast message.data;
			case StereoPannerMessageID.PVolumeRight: pVolumeRight.targetValue = cast message.data;

			default:
				super.parseMessage(message);
		}
	}
}

class StereoPannerMessageID extends DSPMessageID {
	final PVolumeLeft;
	final PVolumeRight;
}
