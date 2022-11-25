package auratests.utils;

import kha.simd.Float32x4;
import utest.Assert;

import aura.types.AudioBuffer.AudioBufferChannelView;
import aura.utils.Interpolator.LinearInterpolator;

class TestLinearInterpolator extends utest.Test {
	static inline var NUM_SAMPLES = 8;

	function test_isInitializedToTargetValue() {
		final interp = new LinearInterpolator(0.0);

		Assert.floatEquals(0.0, interp.currentValue);
		Assert.floatEquals(0.0, interp.lastValue);
		Assert.floatEquals(0.0, interp.targetValue);
	}

	function test_stepSizeIsCorrectForPositiveSteps() {
		final interp = new LinearInterpolator(0.0);
		interp.targetValue = 4.0;

		final stepSize = interp.getLerpStepSize(NUM_SAMPLES);
		Assert.floatEquals(0.5, stepSize);
	}

	function test_stepSizeIsCorrectForNegativeSteps() {
		final interp = new LinearInterpolator(0.0);
		interp.targetValue = -4.0;

		final stepSize = interp.getLerpStepSize(NUM_SAMPLES);
		Assert.floatEquals(-0.5, stepSize);
	}

	function test_stepsReachTargetValue() {
		final interp = new LinearInterpolator(0.0);
		interp.targetValue = 4.0;

		final stepSize = interp.getLerpStepSize(NUM_SAMPLES);

		for (_ in 0...NUM_SAMPLES) {
			interp.currentValue += stepSize;
		}

		Assert.floatEquals(interp.targetValue, interp.currentValue);
	}

	function test_updateLastUpdatesLastAndCurrentValue() {
		final interp = new LinearInterpolator(0.0);

		interp.targetValue = 4.0;

		interp.updateLast();
		Assert.floatEquals(interp.targetValue, interp.lastValue);
		Assert.floatEquals(interp.targetValue, interp.currentValue);
	}

	function test_getLerpStepSizes32x4IsCorrectForPositiveSteps() {
		final interp = new LinearInterpolator(0.0);

		interp.targetValue = 4.0;
		final stepSizes = interp.getLerpStepSizes32x4(NUM_SAMPLES);

		Assert.floatEquals(0.5, Float32x4.getFast(stepSizes, 0));
		Assert.floatEquals(1.0, Float32x4.getFast(stepSizes, 1));
		Assert.floatEquals(1.5, Float32x4.getFast(stepSizes, 2));
		Assert.floatEquals(2.0, Float32x4.getFast(stepSizes, 3));
	}

	function test_getLerpStepSizes32x4IsCorrectForNegativeSteps() {
		final interp = new LinearInterpolator(0.0);

		interp.targetValue = -4.0;
		final stepSizes = interp.getLerpStepSizes32x4(NUM_SAMPLES);

		Assert.floatEquals(-0.5, Float32x4.getFast(stepSizes, 0));
		Assert.floatEquals(-1.0, Float32x4.getFast(stepSizes, 1));
		Assert.floatEquals(-1.5, Float32x4.getFast(stepSizes, 2));
		Assert.floatEquals(-2.0, Float32x4.getFast(stepSizes, 3));
	}

	function test_applySIMD32x4() {
		final samples = new AudioBufferChannelView(NUM_SAMPLES);
		for (i in 0...NUM_SAMPLES) {
			samples[i] = 1.0;
		}

		final interp = new LinearInterpolator(0.0);
		interp.targetValue = 4.0;

		final stepSizes = interp.getLerpStepSizes32x4(NUM_SAMPLES);

		interp.applySIMD32x4(samples, 0, stepSizes);
		Assert.floatEquals(0.5, samples[0]);
		Assert.floatEquals(1.0, samples[1]);
		Assert.floatEquals(1.5, samples[2]);
		Assert.floatEquals(2.0, samples[3]);

		Assert.floatEquals(2.0, interp.currentValue);

		interp.applySIMD32x4(samples, 4, stepSizes);
		Assert.floatEquals(2.5, samples[4]);
		Assert.floatEquals(3.0, samples[5]);
		Assert.floatEquals(3.5, samples[6]);
		Assert.floatEquals(4.0, samples[7]);

		Assert.floatEquals(4.0, interp.currentValue);
	}
}
