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


function optionallyWarnAtomicSafety() {
	#if (haxe_ver < 4.3 || hl_ver < version("1.13.0"))
		static var warned = false;
		if (!warned) {
			trace("[Aura] Warning: Code uses atomic types but the used version of Haxe and/or HL does not support atomics. Correctness may not be guaranteed.");
			warned = true;
		}
	#end
}

#if (haxe_ver >= 4.3 && hl_ver >= version("1.12.0") && !js)

	@:forward
	@:forwardStatics
	abstract AtomicInt(haxe.atomic.AtomicInt) {
		public inline function new(value: Int) {
			this = new haxe.atomic.AtomicInt(value);
		}

		@:op(A + B) public static inline function addI(a: AtomicInt, b: Int): Int { return a.add(b); }
		@:op(A - B) public static inline function subI(a: AtomicInt, b: Int): Int { return a.sub(b); }
		@:op(A & B) public static inline function andI(a: AtomicInt, b: Int): Int { return a.and(b); }
		@:op(A | B) public static inline function  orI(a: AtomicInt, b: Int): Int { return a.or(b);  }
		@:op(A ^ B) public static inline function xorI(a: AtomicInt, b: Int): Int { return a.xor(b); }

		@:op(A + B) public static inline function addA(a: AtomicInt, b: AtomicInt): Int { return a.add(b.load()); }
		@:op(A - B) public static inline function subA(a: AtomicInt, b: AtomicInt): Int { return a.sub(b.load()); }
		@:op(A & B) public static inline function andA(a: AtomicInt, b: AtomicInt): Int { return a.and(b.load()); }
		@:op(A | B) public static inline function  orA(a: AtomicInt, b: AtomicInt): Int { return a.or(b.load());  }
		@:op(A ^ B) public static inline function xorA(a: AtomicInt, b: AtomicInt): Int { return a.xor(b.load()); }

		@:op(A++)   public static inline function inc(a: AtomicInt): Int { return a.add(1); }
		@:op(A--)   public static inline function dec(a: AtomicInt): Int { return a.sub(1); }
	}

#elseif cpp

	@:forward
	@:forwardStatics
	abstract AtomicInt(cpp.AtomicInt) from Int to Int {
		public inline function new(value: Int) {
			this = value;
		}

		public inline function toPtr(): cpp.Pointer<cpp.AtomicInt> {
			final val: cpp.AtomicInt = this; // For some reason, this line is required for correct codegen...
			return cpp.Pointer.addressOf(val);
		}

		public inline function load(): Int {
			return this;
		}

		public inline function store(value: Int): Int {
			// This is suboptimal, but the only thing we can do at the moment
			cpp.AtomicInt.exchangeIf(abstract.toPtr(), 1, value);
			return value;
		}

		// NOTE: add, sub, bitwise ops are not implemented for cpp.AtomicInt
		@:op(A++) public static inline function inc(a: AtomicInt): Int { return cpp.AtomicInt.atomicInc(a.toPtr()); }
		@:op(A--) public static inline function dec(a: AtomicInt): Int { return cpp.AtomicInt.atomicDec(a.toPtr()); }
	}

#else

	@:forward
	@:forwardStatics
	abstract AtomicInt(Int) {
		public inline function new(value: Int) {
			optionallyWarnAtomicSafety();
			this = value;
		}

		public inline function compareExchange(expected: Int, replacement: Int): Int {
			final orig = this;
			if (orig == expected) {
				this = replacement;
			}
			return orig;
		}

		public inline function exchange(value: Int): Int {
			final orig = this;
			this = value;
			return orig;
		}

		public inline function load(): Int {
			return this;
		}

		public inline function store(value: Int): Int {
			return this = value;
		}

		@:op(A + B) public inline function addI(other: Int): Int { final pre = this; this += other; return pre; }
		@:op(A - B) public inline function subI(other: Int): Int { final pre = this; this -= other; return pre; }
		@:op(A & B) public inline function andI(other: Int): Int { final pre = this; this &= other; return pre; }
		@:op(A | B) public inline function  orI(other: Int): Int { final pre = this; this |= other; return pre; }
		@:op(A ^ B) public inline function xorI(other: Int): Int { final pre = this; this ^= other; return pre; }

		@:op(A + B) public inline function addA(other: AtomicInt): Int { final pre = this; this += other.load(); return pre; }
		@:op(A - B) public inline function subA(other: AtomicInt): Int { final pre = this; this -= other.load(); return pre; }
		@:op(A & B) public inline function andA(other: AtomicInt): Int { final pre = this; this &= other.load(); return pre; }
		@:op(A | B) public inline function  orA(other: AtomicInt): Int { final pre = this; this |= other.load(); return pre; }
		@:op(A ^ B) public inline function xorA(other: AtomicInt): Int { final pre = this; this ^= other.load(); return pre; }

		@:op(A++)   public static inline function inc(a: AtomicInt): Int { return a++; }
		@:op(A--)   public static inline function dec(a: AtomicInt): Int { return a--; }
	}

#end

#if (haxe_ver >= 4.3 && hl_ver >= version("1.13.0") && !js)

	@:forward
	@:forwardStatics
	abstract AtomicBool(haxe.atomic.AtomicBool) {
		public inline function new(value: Bool) {
			this = new haxe.atomic.AtomicBool(value);
		}
	}

#else

	@:forward
	@:forwardStatics
	abstract AtomicBool({val: Bool}) { // We need indirection via struct here to not run into compile issues with `this`
		public inline function new(value: Bool) {
			optionallyWarnAtomicSafety();
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
