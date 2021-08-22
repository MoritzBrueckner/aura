// =============================================================================
//	Adapted from
//	https://code.haxe.org/category/data-structures/step-iterator.html
// =============================================================================

package aura.utils;

/**
	Use this as a static extension:

	```haxe
	using StepIterator;

	for (i in (0...10).step(2)) {
		// Do something...
	}
	```
**/
inline function step(iter: IntIterator, step: Int) {
	return @:privateAccess new StepIterator(iter.min, iter.max, step);
}

private class StepIterator {
	var currentIndex: Int;
	final end: Int;
	final step: Int;

	public inline function new(start: Int, end: Int, step: Int) {
		this.currentIndex = start;
		this.end = end;
		this.step = step;
	}

	public inline function hasNext() return currentIndex < end;
	public inline function next() return (currentIndex += step) - step;
}
