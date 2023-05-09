/**
	Various math helper functions.
**/
package aura.utils;

import kha.FastFloat;

import aura.math.Vec3;

/** 1.0 / ln(10) in double precision **/
inline var LN10_INV_DOUBLE: Float = 0.43429448190325181666793241674895398318767547607421875;
/** 1.0 / ln(10) in single precision **/
inline var LN10_INV_SINGLE: kha.FastFloat = 0.4342944920063018798828125;

/** 1.0 / e (Euler's number) **/
inline var E_INV: kha.FastFloat = 0.367879441171442321595523770161460867;

@:pure inline function maxI(a: Int, b: Int): Int {
	return a > b ? a : b;
}

@:pure inline function minI(a: Int, b: Int): Int {
	return a < b ? a : b;
}

@:pure inline function maxF(a: Float, b: Float): Float {
	return a > b ? a : b;
}

@:pure inline function minF(a: Float, b: Float): Float {
	return a < b ? a : b;
}

@:pure inline function lerp(valA: Float, valB: Float, fac: Float) {
	return valA * (1 - fac) + valB * fac;
}

@:pure inline function clampI(val: Int, min: Int = 0, max: Int = 1): Int {
	return maxI(min, minI(max, val));
}

@:pure inline function clampF(val: Float, min: Float = 0.0, max: Float = 1.0): Float {
	return maxF(min, minF(max, val));
}

/**
	Returns the base-10 logarithm of a number.
**/
@:pure inline function log10(v: Float): Float {
	return Math.log(v) * LN10_INV_DOUBLE;
}

/**
	Calculate the counterclockwise angle of the rotation of `vecOther` relative
	to `vecBase` around the rotation axis of `vecNormal`. All input vectors
	*must* be normalized!
**/
@:pure inline function getFullAngleDegrees(vecBase: Vec3, vecOther: Vec3, vecNormal: Vec3): Float {
	final dot = vecBase.dot(vecOther);
	final det = determinant3x3(vecBase, vecOther, vecNormal);
	var radians = Math.atan2(det, dot);

	// Move [-PI, 0) to [PI, 2 * PI]
	if (radians < 0) {
		radians += 2 * Math.PI;
	}
	return radians * 180 / Math.PI;
}

@:pure inline function determinant3x3(col1: Vec3, col2: Vec3, col3: Vec3): Float {
	return (
		col1.x * col2.y * col3.z
		+ col2.x * col3.y * col1.z
		+ col3.x * col1.y * col2.z
		- col1.z * col2.y * col3.x
		- col2.z * col3.y * col1.x
		- col3.z * col1.y * col2.x
	);
}

/**
	Projects the given point to a plane described by its normal vector. The
	origin of the plane is assumed to be at (0, 0, 0).
**/
@:pure inline function projectPointOntoPlane(point: Vec3, planeNormal: Vec3): Vec3 {
	return point.sub(planeNormal.mult(planeNormal.dot(point)));
}

@:pure inline function isPowerOf2(val: Int): Bool {
	return (val & (val - 1)) == 0;
}

@:pure inline function getNearestIndexF(value: Float, stepSize: Float): Int {
	final quotient: Int = Std.int(value / stepSize);
	final remainder: Float = value % stepSize;
	return (remainder > stepSize / 2) ? (quotient + 1) : (quotient);
}

/**
	Calculates the logarithm of base 2 for the given unsigned(!) integer `n`,
	which is the position of the most significant bit set.
**/
@:pure inline function log2Unsigned(n: Int): Int {
	// TODO: optimize? See https://graphics.stanford.edu/~seander/bithacks.html#IntegerLog
	var res = 0;

	var tmp = n >>> 1; // Workaround for https://github.com/HaxeFoundation/haxe/issues/10783
	while (tmp != 0) {
		res++;
		tmp >>>= 1;
	}

	return res;
}

/** Calculates 2^n for a given unsigned integer `n`. **/
@:pure inline function exp2(n: Int): Int {
	return 1 << n;
}

@:pure inline function div4(n: Int): Int {
	return n >>> 2;
}

@:pure inline function mod4(n: Int): Int {
	return n & 3;
}
