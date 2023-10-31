package aura.types;

import haxe.ds.Vector;

#if AURA_BACKEND_HL
	import kha.FastFloat;
#end

typedef ComplexArrayImpl =
	#if AURA_BACKEND_HL
		HL_ComplexArrayImpl
	#elseif js
		JS_ComplexArrayImpl
	#else
		Vector<Complex>
	#end
	;

/**
	An array of complex numbers.
**/
@:forward(length)
@:unreflective
abstract ComplexArray(ComplexArrayImpl) {
	/**
		Create a new zero-initialized complex array.
	**/
	public inline function new(length: Int) {
		#if AURA_BACKEND_HL
			this = inline HL_ComplexArray.create(length);
		#elseif js
			this = new JS_ComplexArrayImpl(length);
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

	/**
		Get the complex number at the given index from the array. Note that it
		is _not_ guaranteed that the returned value will be the same object
		instance than stored in the array, because the array does not store
		instances on every target.
	**/
	@:arrayAccess
	public inline function get(index: Int): Complex {
		#if AURA_BACKEND_HL
			return HL_ComplexArray.get(this, index);
		#elseif js
			return JS_ComplexArrayImpl.get(this, index);
		#else
			return this[index];
		#end
	}

	/**
		Set a complex number at the given array index. It is _guaranteed_ that
		the given value is copied to the array so that the passed complex object
		instance may be kept on the stack if possible.
	**/
	@:arrayAccess
	public inline function set(index: Int, value: Complex): Complex {
		#if AURA_BACKEND_HL
			return HL_ComplexArray.set(this, index, value);
		#elseif js
			return JS_ComplexArrayImpl.set(this, index, value);
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

	#if js
	public inline function subarray(offset: Int, ?length: Int): ComplexArray {
		return this.subarray(offset, length);
	}
	#end

	public inline function copy(): ComplexArray {
		var ret = new ComplexArray(this.length);
		for (i in 0...this.length) {
			#if AURA_BACKEND_HL
				ret[i].setFrom(HL_ComplexArray.get(this, i));
			#elseif js
				ret.set(i, ret.get(i));
			#else
				ret[i] = this[i];
			#end
		}
		return ret;
	}

	/**
		Copy the contents of `other` into this array.
		Both arrays must have the same length.
	**/
	public inline function copyFrom(other: ComplexArray) {
		assert(Error, this.length == other.length);

		for (i in 0...this.length) {
			set(i, other[i]);
		}
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
#end // AURA_BACKEND_HL

#if js
@:forward
private abstract JS_ComplexArrayImpl(js.lib.DataView) {
	public var length(get, never): Int;
	public inline function get_length(): Int {
		return this.byteLength >>> 3;
	}

	public inline function new(length: Int) {
		final buffer = new js.lib.ArrayBuffer(length * 2 * 4);
		this = new js.lib.DataView(buffer, 0, buffer.byteLength);
	}

	public static inline function get(impl: JS_ComplexArrayImpl, index: Int): Complex {
		return new Complex(impl.getFloat32(index * 4 * 2), impl.getFloat32((index * 2 + 1) * 4));
	}

	public static inline function set(impl: JS_ComplexArrayImpl, index: Int, value: Complex): Complex {
		impl.setFloat32(index * 2 * 4, value.real);
		impl.setFloat32((index * 2 + 1) * 4, value.imag);
		return value;
	}

	public inline function subarray(offset: Int, ?length: Int): ComplexArray {
		return cast new js.lib.DataView(this.buffer, offset * 2 * 4, length != null ? length * 2 * 4 : null);
	}
}
#end // js
