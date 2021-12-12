package aura.utils;

import haxe.ds.Vector;

@:generic
class CircularBuffer<T> {

	final data: Vector<T>;
	var readHead: Int;
	var writeHead: Int;
	var length(get, null): Int;

	public inline function new(size: Int) {
		assert(Warning, size != 0);

		this.data = new Vector<T>(size);
		this.length = size;
		this.writeHead = 0;
		this.readHead = 1;
	}

	public inline function setDelay(delaySamples: Int) {
		readHead = writeHead - delaySamples;
		if (readHead < 0) {
			readHead += length;
		}
	}

	public inline function get_length(): Int {
		return data.length;
	}

	public inline function get(): T {
		return data[readHead];
	}

	public inline function set(value: T) {
		data[writeHead] = value;
	}

	public inline function increment() {
		if (++readHead >= length) readHead = 0;
		if (++writeHead >= length) writeHead = 0;
	}

	// TODO
	// public inline function resize(size: Int) {
	// 	var newData = new Vector<T>(size);
	// 	Vector.blit(data, writeHead)
	// }
}
