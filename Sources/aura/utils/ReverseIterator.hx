package aura.utils;

/**
	Use this as a static extension:

	```haxe
	using ReverseIterator;

	for (i in (0...10).reversed()) {
		// Do something...
	}
	```
**/
inline function reversed(iter: IntIterator, step: Int = 1) {
	return @:privateAccess new ReverseIterator(iter.min, iter.max, step);
}

private class ReverseIterator {
	var currentIndex: Int;
	var end: Int;

	var step: Int;

	public inline function new(start: Int, end: Int, step: Int) {
		this.currentIndex = start;
		this.end = end;
		this.step = step;
	}

	public inline function hasNext() return currentIndex > end;
	public inline function next() return (currentIndex -= step) + step;
}
