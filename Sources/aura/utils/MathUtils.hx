/**
	Various math helper functions.
**/
package aura.utils;

import aura.math.Vec3;

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
	Returns the cosine of the angle between two vectors. Vectors must be normalized
	for correct results.
**/
@:pure inline function getAngle(vecA: Vec3, vecB: Vec3): Float {
	return vecA.dot(vecB);
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
