package aura.utils;

import kha.arrays.Float32Array;

import aura.utils.MathUtils;

/**
	Various utilities for resampling (i.e. changing the sample rate) of signals.

	Terminology used in this class for a resampling process:
	- **Source data** describes the data prior to resampling.
	- **Target data** describes the resampled data.
**/
class Resampler {

	/**
		Return the amount of samples required for storing the result of
		resampling data with the given `sourceDataLength` to the
		`targetSampleRate`.
	**/
	public static inline function getResampleLength(sourceDataLength: Int, sourceSampleRate: Hertz, targetSampleRate: Hertz): Int {
		return Math.ceil(sourceDataLength * (targetSampleRate / sourceSampleRate));
	}

	/**
		Transform a position (in samples) relative to the source's sample rate
		into a position (in samples) relative to the target's sample rate and
		return the transformed position.
	**/
	public static inline function sourceSamplePosToTargetPos(sourceSamplePos: Float, sourceSampleRate: Hertz, targetSampleRate: Hertz): Float {
		return sourceSamplePos * (targetSampleRate / sourceSampleRate);
	}

	/**
		Transform a position (in samples) relative to the target's sample rate
		into a position (in samples) relative to the source's sample rate and
		return the transformed position.
	**/
	public static inline function targetSamplePosToSourcePos(targetSamplePos: Float, sourceSampleRate: Hertz, targetSampleRate: Hertz): Float {
		return targetSamplePos * (sourceSampleRate / targetSampleRate);
	}

	/**
		Resample the given `sourceData` from `sourceSampleRate` to
		`targetSampleRate` and write the resampled data into `targetData`.

		It is expected that
		`targetData.length == Resampler.getResampleLength(sourceData.length, sourceSampleRate, targetSampleRate)`,
		otherwise this method may fail (there are no safety checks in place)!
	**/
	public static inline function resampleFloat32Array(sourceData: Float32Array, sourceSampleRate: Hertz, targetData: Float32Array, targetSampleRate: Hertz) {
		for (i in 0...targetData.length) {
			targetData[i] = sampleAtTargetPositionLerp(sourceData, i, sourceSampleRate, targetSampleRate);
		}
	}

	/**
		Sample the given `sourceData` at `targetSamplePos` (position in samples
		relative to the target data) using linear interpolation for values
		between source samples.

		@param sourceSampleRate The sample rate of the source data
		@param targetSampleRate The sample rate of the target data
	**/
	public static function sampleAtTargetPositionLerp(sourceData: Float32Array, targetSamplePos: Float, sourceSampleRate: Hertz, targetSampleRate: Hertz): Float {
		assert(Critical, targetSamplePos >= 0.0);

		final sourceSamplePos = targetSamplePosToSourcePos(targetSamplePos, sourceSampleRate, targetSampleRate);

		final maxPos = sourceData.length - 1;
		final pos1 = Math.floor(sourceSamplePos);
		final pos2 = pos1 + 1;

		final value1 = (pos1 > maxPos) ? sourceData[maxPos] : sourceData[pos1];
		final value2 = (pos2 > maxPos) ? sourceData[maxPos] : sourceData[pos2];

		return lerp(value1, value2, sourceSamplePos - Math.floor(sourceSamplePos));
	}
}
