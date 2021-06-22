package aura;

import aura.MathUtils.clampF;

/**
	Integer representing a Hertz value.
**/
typedef Hertz = Int;

abstract Balance(Float) from Float to Float {
	public static inline var LEFT: Balance = 0.0;
	public static inline var CENTER: Balance = 0.5;
	public static inline var RIGHT: Balance = 1.0;

	inline function new(value: Float) {
		this = clampF(value);
	}

	public static inline function fromAngle(angle: Angle): Balance {
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
