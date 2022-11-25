package auratests.types;

import utest.Assert;

import aura.types.Complex;
import aura.types.ComplexArray;

class TestComplexArray extends utest.Test {
	var array: ComplexArray;

	function setup() {
		array = new ComplexArray(4);
	}

	function teardown() {}

	function test_length() {
		Assert.equals(4, array.length);
	}

	@:depends(test_length)
	function test_isZeroInitialized() {
		for (i in 0...array.length) {
			var tmp = array[i];
			Assert.equals(0.0, tmp.real);
			Assert.equals(0.0, tmp.imag);
		}
	}

	function test_getSetBasicFunctionality() {
		array[0] = new Complex(3.14, 1.1);
		Assert.floatEquals(3.14, array[0].real);
		Assert.floatEquals(1.1, array[0].imag);
	}

	function test_getSetCorrectStride() {
		array[0] = new Complex(3.14, 1.1);
		array[1] = new Complex(9.9, 1.23);
		Assert.floatEquals(9.9, array[1].real);
		Assert.floatEquals(1.23, array[1].imag);
		Assert.floatEquals(3.14, array[0].real); // Ensure no overrides happen
		Assert.floatEquals(1.1, array[0].imag);
	}

	function test_getSetArrayCopiesValues() {
		var tmp = new Complex(3.14, 1.1);
		array[0] = tmp;
		Assert.isTrue(tmp != array[0]);
	}
}
