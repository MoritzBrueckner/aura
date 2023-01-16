package auratests.utils;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.utils.Resampler;

class TestResampler extends utest.Test {
	final sourceData = new Float32Array(4);
	final sourceSampleRate = 100;

	function setupClass() {
		sourceData[0] = 0.0;
		sourceData[1] = 1.0;
		sourceData[2] = 2.0;
		sourceData[3] = 3.0;
	}

	function test_getResampleLength() {
		Assert.equals(Std.int(sourceData.length / 2), Resampler.getResampleLength(sourceData.length, sourceSampleRate, Std.int(sourceSampleRate / 2)));
		Assert.equals(sourceData.length * 2, Resampler.getResampleLength(sourceData.length, sourceSampleRate, sourceSampleRate * 2));
	}

	function test_sourceSamplePosToTargetPos() {
		Assert.floatEquals(1.0, Resampler.sourceSamplePosToTargetPos(2.0, 100, 50));
		Assert.floatEquals(4.0, Resampler.sourceSamplePosToTargetPos(2.0, 100, 200));
	}

	function test_targetSamplePosToSourcePos() {
		Assert.floatEquals(4.0, Resampler.targetSamplePosToSourcePos(2.0, 100, 50));
		Assert.floatEquals(1.0, Resampler.targetSamplePosToSourcePos(2.0, 100, 200));
	}

	function test_sampleAtTargetPositionLerp_SamplesExactValuesAtDiscretePositions() {
		Assert.floatEquals(0.0, Resampler.sampleAtTargetPositionLerp(sourceData, 0.0, sourceSampleRate, 100));
		Assert.floatEquals(1.0, Resampler.sampleAtTargetPositionLerp(sourceData, 1.0, sourceSampleRate, 100));
	}

	function test_sampleAtTargetPositionLerp_InterpolatesLinearlyBetweenDiscreteSamples() {
		Assert.floatEquals(0.5, Resampler.sampleAtTargetPositionLerp(sourceData, 0.5, sourceSampleRate, 100));
		Assert.floatEquals(0.3, Resampler.sampleAtTargetPositionLerp(sourceData, 0.3, sourceSampleRate, 100));
	}

	function test_sampleAtTargetPositionLerp_AssertsSamplePositionNotNegative() {
		#if (AURA_ASSERT_LEVEL!="NoAssertions")
		Assert.raises(() -> {
			Resampler.sampleAtTargetPositionLerp(sourceData, -1.0, sourceSampleRate, 100);
		});
		#else
		Assert.pass();
		#end
	}

	function test_sampleAtTargetPositionLerp_ClampsValuesOutOfUpperDataBounds() {
		Assert.floatEquals(3.0, Resampler.sampleAtTargetPositionLerp(sourceData, 3.5, sourceSampleRate, 100));
		Assert.floatEquals(3.0, Resampler.sampleAtTargetPositionLerp(sourceData, 4.0, sourceSampleRate, 100));
	}

	function test_sampleAtTargetPositionLerp_DifferentSampleRatesUsed() {
		Assert.floatEquals(0.0, Resampler.sampleAtTargetPositionLerp(sourceData, 0.0, sourceSampleRate, Std.int(sourceSampleRate / 2)));
		Assert.floatEquals(1.0, Resampler.sampleAtTargetPositionLerp(sourceData, 0.5, sourceSampleRate, Std.int(sourceSampleRate / 2)));
		Assert.floatEquals(2.0, Resampler.sampleAtTargetPositionLerp(sourceData, 1.0, sourceSampleRate, Std.int(sourceSampleRate / 2)));

		Assert.floatEquals(0.0, Resampler.sampleAtTargetPositionLerp(sourceData, 0.0, sourceSampleRate, sourceSampleRate * 2));
		Assert.floatEquals(0.25, Resampler.sampleAtTargetPositionLerp(sourceData, 0.5, sourceSampleRate, sourceSampleRate * 2));
		Assert.floatEquals(0.5, Resampler.sampleAtTargetPositionLerp(sourceData, 1.0, sourceSampleRate, sourceSampleRate * 2));
	}

	function test_resampleFloat32Array() {
		final targetData = new Float32Array(8);

		Resampler.resampleFloat32Array(sourceData, 100, targetData, 200);

		Assert.floatEquals(0.0, targetData[0]);
		Assert.floatEquals(0.5, targetData[1]);
		Assert.floatEquals(1.0, targetData[2]);
		Assert.floatEquals(1.5, targetData[3]);
		Assert.floatEquals(2.0, targetData[4]);
		Assert.floatEquals(2.5, targetData[5]);
		Assert.floatEquals(3.0, targetData[6]);
		Assert.floatEquals(3.0, targetData[7]); // Don't extrapolate data
	}
}
