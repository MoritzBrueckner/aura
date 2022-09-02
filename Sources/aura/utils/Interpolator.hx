package aura.utils;

import kha.FastFloat;
import kha.simd.Float32x4;

import aura.types.AudioBuffer.AudioBufferChannelView;

class LinearInterpolator {
	public var lastValue: FastFloat;
	public var targetValue: FastFloat;
	public var currentValue: FastFloat;

	public inline function new(targetValue: FastFloat) {
		this.targetValue = this.currentValue = this.lastValue = targetValue;
	}

	public inline function updateLast() {
		this.lastValue = this.currentValue = this.targetValue;
	}

	public inline function getLerpStepSize(numSteps: Int): FastFloat {
		return (this.targetValue - this.lastValue) / numSteps;
	}

	/**
		Return a 32x4 SIMD register where each value contains the step size times
		its index for efficient usage in `LinearInterpolator.applySIMD32x4()`.
	**/
	public inline function getLerpStepSizes32x4(numSteps: Int): Float32x4 {
		final stepSize = getLerpStepSize(numSteps);
		return Float32x4.mul(Float32x4.loadAllFast(stepSize), Float32x4.loadFast(1.0, 2.0, 3.0, 4.0));
	}

	/**
		Applies four consecutive interpolation steps to `samples` (multiplicative)
		using Kha's 32x4 SIMD API, starting at index `i`. `stepSizes32x4` must
		be a SIMD register filled with `LinearInterpolator.getLerpStepSizes32x4()`.

		There is no bound checking in place! It is assumed that 4 samples can
		be accessed starting at `i`.
	**/
	public inline function applySIMD32x4(samples: AudioBufferChannelView, i: Int, stepSizes32x4: Float32x4) {
		var rampValues = Float32x4.add(Float32x4.loadAllFast(currentValue), stepSizes32x4);
		currentValue = Float32x4.getFast(rampValues, 3);

		var signalValues = Float32x4.loadFast(samples[i], samples[i + 1], samples[i + 2], samples[i + 3]);
		var res = Float32x4.mul(signalValues, rampValues);
		samples[i + 0] = Float32x4.getFast(res, 0);
		samples[i + 1] = Float32x4.getFast(res, 1);
		samples[i + 2] = Float32x4.getFast(res, 2);
		samples[i + 3] = Float32x4.getFast(res, 3);
	}
}
