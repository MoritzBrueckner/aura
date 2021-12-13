package aura.dsp.panner;

import kha.arrays.Float32Array;

import aura.utils.MathUtils;

class StereoPanner extends Panner {
	public function update3D() {
		final listener = Aura.listener;
		final dirToChannel = handle.location.sub(listener.location);

		if (dirToChannel.length == 0) {
			handle.setBalance(Balance.CENTER);
			handle.channel.sendMessage({ id: PDstAttenuation, data: 1.0 });
			return;
		}

		final look = listener.look;
		final up = listener.right.cross(look).normalized();

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
		handle.setBalance(angle);

		calculateAttenuation(dirToChannel);
		calculateDoppler();
	}

	override public function reset3D() {
		handle.setBalance(Balance.CENTER);

		super.reset3D();
	}

	function process(buffer:Float32Array, bufferLength:Int) {}
}
