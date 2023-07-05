package aura.utils;

import kha.arrays.Float32Array;

class TestSignals {
	/**
		Fill the given `array` with a signal that represents a DC or 0Hz signal.
	**/
	public static inline function fillDC(array: Float32Array) {
		for (i in 0...array.length) {
			array[i] = (i == 0) ? 0.0 : 1.0;
		}
	}

	/**
		Fill the given `array` with a single unit impulse.
	**/
	public static inline function fillUnitImpulse(array: Float32Array) {
		for (i in 0...array.length) {
			array[i] = (i == 0) ? 1.0 : 0.0;
		}
	}
}
