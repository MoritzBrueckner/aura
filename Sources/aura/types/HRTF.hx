package aura.types;

import haxe.ds.Vector;

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

