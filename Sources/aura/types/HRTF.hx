package aura.types;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.math.Vec3;
import aura.utils.BufferUtils;
import aura.utils.MathUtils;
import aura.utils.Pointer;

using aura.utils.ReverseIterator;

/**
	The entirety of all fields with their respective HRIRs (head related impulse
	responses).
**/
@:structInit class HRTF {
	/**
		The sample rate of the HRIRs.
	**/
	public final sampleRate: Int;

	/**
		The number of channels of the HRIRs.
	**/
	public final numChannels: Int;

	/**
		The amount of samples of each HRIR (per channel).
	**/
	public final hrirSize: Int;

	/**
		The amount of HRIRs in this HRTF.
	**/
	public final hrirCount: Int;

	/**
		The fields of this HRTF.
	**/
	public final fields: Vector<Field>;

	/**
		The longest delay of any HRIR contained in this HRTF in samples. Useful
		to preallocate enough memory for delay lines (use
		`Math.ceil(maxDelayLength)`).
	**/
	public final maxDelayLength: Float;

	/**
		Create a bilinearly interpolated HRIR for the given direction (distance
		is fixed for now) and store it in `outputBuf`. The length of the HRIR's
		impulse response as well as the interpolated delay (in samples) is
		stored in `outImpulseLength` and `outDelay`.

		@param elevation Elevation (polar) angle from 0 (bottom) to 180 (top).
		@param azimuth Azimuthal angle from 0 (front) to 360, clockwise.
	**/
	public function getInterpolatedHRIR(
		elevation: Float, azimuth: Float,
		outputBuf: Float32Array, outImpulseLength: Pointer<Int>, outDelay: Pointer<Int>
	) {
		/**
			Used terms in this function:

			low/high: the elevations of the closest HRIR below and above the
				given elevation

			left/right: the azimuths of the closest HRIR left and right to the
				given azimuth (the azimuth angle is clockwise, so the directions
				left/right are meant from the perspective from the origin)
		**/
		clearBuffer(outputBuf);

		// TODO Use fixed distance for now...
		final field = this.fields[this.fields.length - 1];

		final elevationStep = 180 / field.evCount;
		final elevationIndexLow = Std.int(elevation / elevationStep);
		final elevationIndexHigh = elevationIndexLow + 1;
		var elevationWeight = (elevation % elevationStep) / elevationStep;

		// Calculate the offset into the HRIR arrays. Diffferent elevations may
		// have different amounts of azimuths/HRIRs
		// TODO: store offset per elevation for faster access?
		var elevationHRIROffsetLow = 0;
		for (j in 0...elevationIndexLow) {
			elevationHRIROffsetLow += field.azCount[j];
		}
		final elevationHRIROffsetHigh = elevationHRIROffsetLow + field.azCount[elevationIndexHigh - 1];

		var delay = 0.0;
		var hrirLength = 0;
		for (ev in 0...2) {
			final elevationIndex = ev == 0 ? elevationIndexLow : elevationIndexHigh;
			final elevationHRIROffset = ev == 0 ? elevationHRIROffsetLow : elevationHRIROffsetHigh;

			// TODO: azCount can be 0, leading to NaN errors...
			final azimuthStep = 360 / field.azCount[elevationIndex];
			final azimuthIndexLeft = Std.int(azimuth / azimuthStep);
			var azimuthIndexRight = azimuthIndexLeft + 1;
			if (azimuthIndexRight == field.azCount[elevationIndex]) {
				azimuthIndexRight = 0;
			}
			final azimuthWeight = (azimuth % azimuthStep) / azimuthStep;

			// trace(azimuthStep, azimuthIndexLeft, azimuthIndexRight, azimuthWeight);

			final hrirLeft = field.hrirs[elevationHRIROffset + azimuthIndexLeft];
			final hrirRight = field.hrirs[elevationHRIROffset + azimuthIndexRight];

			final evWeight = ev == 0 ? 1 - elevationWeight : elevationWeight;

			// Interpolate delay
			delay += lerp(hrirLeft.delays[0], hrirRight.delays[0], azimuthWeight) * evWeight;

			// Interpolate coefficients
			final invWeight = 1 - azimuthWeight;
			for (i in 0...outputBuf.length) {
				final leftCoeff = i < hrirLeft.coeffs.length ? hrirLeft.coeffs[i] * invWeight : 0.0;
				final rightCoeff = i < hrirRight.coeffs.length ? hrirRight.coeffs[i] * azimuthWeight : 0.0;
				outputBuf[i] += (leftCoeff + rightCoeff) * evWeight;
			}

			var maxLength = maxI(hrirLeft.coeffs.length, hrirRight.coeffs.length);
			if (maxLength > hrirLength) {
				hrirLength = maxLength;
			}
		}

		outDelay.set(Math.round(delay));
		outImpulseLength.set(hrirLength);
	}
}

/**
	A field represents the entirety of HRIRs (head related impulse responses)
	for a given distance to the listener. Imagine this as one layer of a sphere
	around the listener.
**/
class Field {
	/**
		Distance to the listener, in millimeters (in the range 50mm-2500mm).
	**/
	public var distance: Int;

	/**
		Total HRIR count (for all elevations combined).
	**/
	public var hrirCount: Int;

	/**
		Number of elevations in this field. Elevations start at -90 degrees
		(bottom) and go up to 90 degrees.
	**/
	public var evCount: Int;

	/**
		Number of azimuths (and HRIRs) per elevation. Azimuths construct a full
		circle (360 degrees), starting at the front of the listener and going
		clockwise.
	**/
	public var azCount: Vector<Int>;

	/**
		All HRIRs in this field.
	**/
	public var hrirs: Vector<HRIR>;

	public function new() {}
}

/**
	A single HRIR (head related impulse response)
**/
class HRIR {
	/**
		The impulse response coefficients. If the HRIR is stereo, the
		coefficients are interleaved (left/right).
	**/
	// TODO: Change to Float32Array
	public var coeffs: Vector<Float>;

	/**
		Delay of the impulse response per channel in samples.
	**/
	// TODO: Don't forget to also change this when resampling!
	public var delays: Vector<Float>;

	public function new() {}
}

