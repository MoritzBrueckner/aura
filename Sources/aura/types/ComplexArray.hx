package aura.types;

import haxe.ds.Vector;

#if AURA_BACKEND_HL
	import kha.FastFloat;
#end

typedef ComplexArrayImpl =
	#if AURA_BACKEND_HL
		HL_ComplexArrayImpl
	#else
		Vector<Complex>
	#end
	;

@:forward(length)
@:unreflective
abstract ComplexArray(ComplexArrayImpl) {
	/**
		Create a new zero-initialized complex array.
	**/
	public inline function new(length: Int) {
		#if AURA_BACKEND_HL
			this = inline HL_ComplexArray.create(length);
		#else
			this = new ComplexArrayImpl(length);
			for (i in 0...length) {
				this[i] = Complex.newZero();
			}
		#end
	}

	#if AURA_BACKEND_HL
	public inline function free() {
		HL_ComplexArray.free(this);
	}
	#end

	@:arrayAccess
	public inline function get(index: Int): Complex {
		#if AURA_BACKEND_HL
			return HL_ComplexArray.get(this, index);
		#else
			return this[index];
		#end
	}

	@:arrayAccess
	public inline function set(index: Int, value: Complex): Complex {
		#if AURA_BACKEND_HL
			return HL_ComplexArray.set(this, index, value);
		#else
			// Copy to array to keep original value on stack
			this[index].setFrom(value);

			// It is important to return the element from the array instead of
			// the `value` parameter, so that Haxe doesn't create a temporary
			// complex object (allocated on the heap in the worst case) to store
			// the state of `value` before calling `setFrom()` above...
			return this[index];
		#end
	}
}

#if AURA_BACKEND_HL
private class HL_ComplexArrayImpl {
	public var self: hl.Bytes;
	public var length: Int;

	public inline function new() {}
}

private class HL_ComplexArray {
	public static inline function create(length: Int): ComplexArrayImpl {
		final impl = new ComplexArrayImpl();
		impl.length = length;
		if (length > 0) {
			impl.self = aura_hl_complex_array_alloc(length);
			if (impl.self == null) {
				throw 'Could not allocate enough memory for complex array of length ${length}';
			}
		}
		return impl;
	}

	public static inline function free(impl: ComplexArrayImpl) {
		aura_hl_complex_array_free(impl.self);
	}

	public static inline function get(impl: ComplexArrayImpl, index: Int): Complex {
		return aura_hl_complex_array_get(impl.self, index);
	}

	public static inline function set(impl: ComplexArrayImpl, index: Int, value: Complex): Complex {
		return aura_hl_complex_array_set(impl.self, index, value.real, value.imag);
	}

	@:hlNative("aura_hl", "complex_array_alloc")
	static function aura_hl_complex_array_alloc(length: Int): hl.Bytes { return null; }

	@:hlNative("aura_hl", "complex_array_free")
	static function aura_hl_complex_array_free(complexArray: hl.Bytes): Void {}

	@:hlNative("aura_hl", "complex_array_get")
	static function aura_hl_complex_array_get(complexArray: hl.Bytes, index: Int): Complex { return Complex.newZero(); }

	@:hlNative("aura_hl", "complex_array_set")
	static function aura_hl_complex_array_set(complexArray: hl.Bytes, index: Int, real: FastFloat, imag: FastFloat): Complex { return Complex.newZero(); }
}
#end
