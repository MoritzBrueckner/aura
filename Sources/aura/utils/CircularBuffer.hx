package aura.utils;

import kha.FastFloat;
import kha.arrays.Float32Array;

import aura.utils.BufferUtils;

class CircularBuffer {
	final data: Float32Array;
	var readHead: Int;
	var writeHead: Int;
	public var length(get, null): Int;
	public var delay = 0;

	public inline function new(size: Int) {
		assert(Warning, size > 0);

		this.data = createEmptyF32Array(size);
		this.length = size;
		this.writeHead = 0;
		this.readHead = 1;
	}

	public inline function setDelay(delaySamples: Int) {
		delay = delaySamples;
		readHead = writeHead - delaySamples;
		if (readHead < 0) {
			readHead += length;
		}
	}

	public inline function get_length(): Int {
		return data.length;
	}

	public inline function get(): FastFloat {
		return data[readHead];
	}

	public inline function set(value: FastFloat) {
		data[writeHead] = value;
	}

	public inline function increment() {
		if (++readHead >= length) readHead = 0;
		if (++writeHead >= length) writeHead = 0;
	}
}
