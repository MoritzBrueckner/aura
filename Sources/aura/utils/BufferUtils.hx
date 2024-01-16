package aura.utils;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.Float32Array;

inline function fillBuffer(buffer: Float32Array, value: FastFloat, length: Int = -1) {
	for (i in 0...(length == -1 ? buffer.length : length)) {
		buffer[i] = value;
	}
}

inline function clearBuffer(buffer: Float32Array) {
	#if hl
		hl_fillByteArray(buffer, 0);
	#else
		fillBuffer(buffer, 0);
	#end
}

inline function initZeroesVecI(vector: Vector<Int>) {
	#if (haxe_ver >= "4.300")
		vector.fill(0);
	#else
		for (i in 0...vector.length) {
			vector[i] = 0;
		}
	#end
}

inline function initZeroesF64(vector: Vector<Float>) {
	#if (haxe_ver >= "4.300")
		vector.fill(0);
	#else
		for (i in 0...vector.length) {
			vector[i] = 0;
		}
	#end
}

inline function initZeroesF32(vector: Vector<FastFloat>) {
	#if (haxe_ver >= "4.300")
		vector.fill(0);
	#else
		for (i in 0...vector.length) {
			vector[i] = 0;
		}
	#end
}

/**
	Creates an empty integer vector with the given length. It is guaranteed to
	be always filled with 0, independent of the target.
**/
inline function createEmptyVecI(length: Int): Vector<Int> {
	#if target.static
		return new Vector<Int>(length);
	#else
		// On dynamic targets, vectors hold `null` after creation instead of 0
		final vec = new Vector<Int>(length);
		inline initZeroesVecI(vec);
		return vec;
	#end
}

/**
	Creates an empty float vector with the given length. It is guaranteed to be
	always filled with 0, independent of the target.
**/
inline function createEmptyVecF64(length: Int): Vector<Float> {
	#if target.static
		return new Vector<Float>(length);
	#else
		final vec = new Vector<Float>(length);
		inline initZeroesF64(vec);
		return vec;
	#end
}

inline function createEmptyVecF32(length: Int): Vector<FastFloat> {
	#if target.static
		return new Vector<FastFloat>(length);
	#else
		final vec = new Vector<FastFloat>(length);
		inline initZeroesF32(vec);
		return vec;
	#end
}

inline function createEmptyF32Array(length: Int): Float32Array {
	final out = new Float32Array(length);
	#if !js
		clearBuffer(out);
	#end
	return out;
}

#if hl
inline function hl_fillByteArray(a: kha.arrays.ByteArray, byteValue: Int) {
	(a.buffer: hl.Bytes).fill(0, a.byteLength, byteValue);
}
#end
