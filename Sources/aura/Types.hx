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

	public inline function matchesIndex(index: Int): Bool {
		return ((1 << index) & this) != 0;
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
	@:forward
	@:forwardStatics
	abstract AtomicInt(cpp.AtomicInt) from Int to Int {
		public inline function toPtr(): cpp.Pointer<cpp.AtomicInt> {
			final val: cpp.AtomicInt = this; // For some reason, this line is required for correct codegen...
			return cpp.Pointer.addressOf(val);
		}
	}
#else
	typedef AtomicInt = Int;
#end

#if (haxe_ver >= 4.3 && hl_ver >= version("1.13.0") && !js)
	typedef AtomicBool = haxe.atomic.AtomicBool;
#else
	@:forward
	@:forwardStatics
	abstract AtomicBool({val: Bool}) { // We need indirection via struct here to not run into compile issues with `this`
		public inline function new(value: Bool) {
			this = {val: value};
		}

		public inline function compareExchange(expected: Bool, replacement: Bool): Bool {
			final orig = this.val;
			if (orig == expected) {
				this.val = replacement;
			}
			return orig;
		}

		public inline function exchange(value: Bool): Bool {
			final orig = this.val;
			this.val = value;
			return orig;
		}

		public inline function load(): Bool {
			return this.val;
		}

		public inline function store(value: Bool): Bool {
			return this.val = value;
		}
	}
#end
