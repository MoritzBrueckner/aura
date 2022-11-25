package auratests.utils;

import utest.Assert;

import aura.utils.MathUtils;

class TestMathUtils extends utest.Test {

	function test_maxMin() {
		Assert.equals(18, minI(42, 18));
		Assert.equals(18, minI(18, 42));
		Assert.equals(-99, minI(-99, 42));

		Assert.equals(42, maxI(42, 18));
		Assert.equals(42, maxI(18, 42));
		Assert.equals(42, maxI(-99, 42));

		Assert.equals(3.14, minF(3.14, 11.11));
		Assert.equals(3.14, minF(11.11, 3.14));
		Assert.equals(-28.1, minF(-28.1, 3.07));

		Assert.equals(11.11, maxF(3.14, 11.11));
		Assert.equals(11.11, maxF(11.11, 3.14));
		Assert.equals(3.07, maxF(-28.1, 3.07));
	}
}
