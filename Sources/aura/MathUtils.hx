/**
	Various math helper functions.
**/
package aura;

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
