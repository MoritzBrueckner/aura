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
	Calculate the counterclockwise angle of `vecOther` relative to `vecBase`.
**/
@:pure inline function getFullAngleDegrees(vecBase: Vec3, vecOther: Vec3): Float {
	final dX = vecOther.x - vecBase.x;
	final dY = vecOther.y - vecBase.y;
	var radians = (dX == 0 || dY == 0) ? 0.0 : Math.atan2(dY, dX);
	if (radians < 0) {
		// Move [-PI, 0) to [PI, 2 * PI]
		radians += 2 * Math.PI;
	}
	return radians * 180 / Math.PI;
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
