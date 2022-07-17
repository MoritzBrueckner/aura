package aura;

import aura.utils.MathUtils.clampF;

/**
	Integer representing a Hertz value.
**/
typedef Hertz = Int;

/**
	Float representing milliseconds.
**/
typedef Millisecond = Float;

enum abstract Channels(Int) {
	var Left = 1 << 0;
	var Right = 1 << 1;

	var All = ~0;

	public inline function matches(mask: Channels): Bool {
		return (this & mask.asInt()) != 0;
	}

	inline function asInt(): Int {
		return this;
	}
}

abstract Balance(Float) from Float to Float {
	public static inline var LEFT: Balance = 0.0;
	public static inline var CENTER: Balance = 0.5;
	public static inline var RIGHT: Balance = 1.0;

	inline function new(value: Float) {
		this = clampF(value);
	}

	@:from public static inline function fromAngle(angle: Angle): Balance {
		return switch (angle) {
			case Deg(deg): (deg + 90) / 180;
			case Rad(rad): (rad + Math.PI / 2) / Math.PI;
		}
	}

	@:op(~A) public function invert() {
		return 1.0 - this;
	}
}

enum Angle {
	Deg(deg: Int);
	Rad(rad: Float);
}

#if cpp
	typedef AtomicInt = cpp.AtomicInt;
#else
	typedef AtomicInt = Int;
#end
