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
	Projects the given point to a plane described by its normal vector. The
	origin of the plane is assumed to be at (0, 0, 0).
**/
@:pure inline function projectPointOntoPlane(point: Vec3, planeNormal: Vec3): Vec3 {
	return point.sub(planeNormal.mult(planeNormal.dot(point)));
}

@:pure inline function isPowerOf2(val: Int): Bool {
	return (val & (val - 1)) == 0;
}
