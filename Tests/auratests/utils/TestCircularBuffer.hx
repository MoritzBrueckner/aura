package auratests.utils;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.utils.BufferUtils;
import aura.utils.CircularBuffer;

import Utils;

@:access(aura.utils.CircularBuffer)
class TestCircularBuffer extends utest.Test {
	var buffer: CircularBuffer;

	function setup() {
		buffer = new CircularBuffer(8);
	}

	function teardown() {}

	function test_new_assertThatSizeIsPositiveNumber() {
		assertRaisesAssertion(() -> {
			new CircularBuffer(0);
		});

		assertRaisesAssertion(() -> {
			new CircularBuffer(-1);
		});
	}

	function test_new_dataInitializedToZero() {
		// Please note that this test always succeeds on JS and has additional
		// false negatives on other targets, there the test still succeeds if data
		// is not actively initialized but the values are still 0
		// TODO If Aura has it's own array types at some point in time, implement
		//  active poisoning of values if unit tests are run

		final compareArray = createEmptyF32Array(buffer.length);
		assertEqualsFloat32Array(compareArray, buffer.data);
	}
}
