package aura.utils;

class LinearInterpolator {
	public var lastValue: Float;
	public var targetValue: Float;
	public var currentValue: Float;

	public inline function new(targetValue: Float) {
		this.targetValue = this.currentValue = this.lastValue = targetValue;
	}

	public inline function updateLast() {
		this.lastValue = this.currentValue = this.targetValue;
	}

	public inline function getLerpStepSize(numSteps: Int): Float {
		return (this.targetValue - this.lastValue) / numSteps;
	}
}
