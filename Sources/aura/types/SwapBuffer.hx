package aura.types;

import haxe.ds.Vector;

import dsp.Complex;

// TODO: Make generic in some way
class SwapBuffer {
	public final length: Int;
	public final data1: Array<Complex>;
	public final data2: Array<Complex>;

	var writeData: Array<Complex>;
	var readData: Array<Complex>;

	var isReading = false;

	public function new(length: Int) {
		this.length = length;
		this.data1 = new Array<Complex>();
		data1.resize(length);
		this.data2 = new Array<Complex>();
		data2.resize(length);

		writeData = data1;
		readData = data2;
	}

	public inline function write(src: Array<Complex>, srcStart: Int, dstStart: Int, length: Int) {
		for (i in srcStart...srcStart + length) {
			writeData[dstStart + i] = src[i].copy(); // TODO: Investigate possible memory leaks through allocation
		}
	}

	public inline function writeVecF(src: Vector<Float>, srcStart: Int, dstStart: Int, length: Int) {
		for (i in srcStart...srcStart + length) {
			writeData[dstStart + i] = Complex.fromReal(src[i]);
		}
	}

	public inline function writeZero(dstStart: Int, dstEnd: Int) {
		for (i in dstStart...dstEnd) {
			writeData[i] = Complex.zero;
		}
	}

	public inline function read(dst: Array<Complex>, srcStart: Int, dstStart: Int, length: Int) {
		for (i in srcStart...srcStart + length) {
			dst[dstStart + i - srcStart] = readData[i].copy();
		}
	}

	public inline function swap() {
		while (isReading) {}

		// #if cpp
		// 	untyped __cpp__("std::swap({0}, {1})", writeData, readData);
		// #else
			final tmp = writeData;
			writeData = readData;
			readData = tmp;
		// #end
	}

	public inline function setReadLock() {
		isReading = true;
	}

	public inline function removeReadLock() {
		isReading = false;
	}
}
