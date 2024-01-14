package auratests.types;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.types.AudioBuffer;
import aura.utils.BufferUtils;

import Utils;

class TestAudioBuffer extends utest.Test {
	var buffer: AudioBuffer;

	function setup() {
		buffer = new AudioBuffer(2, 8);
	}

	function teardown() {}

	function test_numChannels() {
		Assert.equals(2, buffer.numChannels);

		assertRaisesAssertion(() -> {
			new AudioBuffer(0, 8);
		});

		assertRaisesAssertion(() -> {
			new AudioBuffer(-1, 8);
		});
	}

	function test_channelLength() {
		Assert.equals(8, buffer.channelLength);

		assertRaisesAssertion(() -> {
			new AudioBuffer(2, 0);
		});

		assertRaisesAssertion(() -> {
			new AudioBuffer(2, -1);
		});
	}

	function test_AudioBufferChannelView_GetSetWithSameIndexAccessSameValue() {
		final view0 = buffer.getChannelView(0);
		final view1 = buffer.getChannelView(1);

		view0[1] = 8.0;
		view1[6] = 4.0;

		Assert.floatEquals(8.0, view0[1]);
		Assert.floatEquals(4.0, view1[6]);
	}

	function test_channelViewsDoNotOverlap() {
		final view0 = buffer.getChannelView(0);
		final view1 = buffer.getChannelView(1);

		// Fill views one after each other
		for (i in 0...buffer.numChannels) {
			view0[i] = 0.0;
		}

		for (i in 0...buffer.numChannels) {
			view1[i] = 1.0;
		}

		for (i in 0...buffer.numChannels) {
			Assert.floatEquals(0.0, view0[i]);
		}
	}

	function test_interleaveToFloat32Array_assertionIfCopyingNegativeAmountOfSamples() {
		final array = new Float32Array(4);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, 0, 0, -1);
		});
	}

	function test_interleaveToFloat32Array_assertionIfArrayIsTooSmall() {
		final array = new Float32Array(4);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, 0, 0, buffer.channelLength);
		});
	}

	function test_interleaveToFloat32Array_assertionIfSourceOffsetIsNegative() {
		final array = new Float32Array(64);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, -1, 0, buffer.channelLength);
		});
	}

	function test_interleaveToFloat32Array_assertionIfTargetOffsetIsNegative() {
		final array = new Float32Array(16);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, 0, -1, buffer.channelLength);
		});
	}

	function test_interleaveToFloat32Array_assertionIfSourceOffsetIsTooLarge() {
		final array = new Float32Array(64);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, 500, 0, buffer.channelLength);
		});
	}

	function test_interleaveToFloat32Array_assertionIfTargetOffsetIsTooLarge() {
		final array = new Float32Array(16);

		assertRaisesAssertion(() -> {
			buffer.interleaveToFloat32Array(array, 0, 500, buffer.channelLength);
		});
	}

	function test_clear() {
		fillBuffer(buffer.getChannelView(0), 1.0);
		fillBuffer(buffer.getChannelView(1), -1.0);

		buffer.clear();

		final zeroArray = new Float32Array(buffer.numChannels * buffer.channelLength);
		clearBuffer(zeroArray);

		assertEqualsFloat32Array(zeroArray, buffer.rawData);
	}

	function test_interleaveToFloat32Array_numSamplesToCopy() {
		final view0 = buffer.getChannelView(0);
		final view1 = buffer.getChannelView(1);

		// Fill views one after each other
		for (i in 0...buffer.channelLength) {
			view0[i] = i;
		}
		for (i in 0...buffer.channelLength) {
			view1[i] = 8 + i;
		}

		final targetArray = new Float32Array(32);
		clearBuffer(targetArray);

		final compareArray = new Float32Array(32);
		clearBuffer(compareArray);
		compareArray[0] = 0;
		compareArray[1] = 8;
		compareArray[2] = 1;
		compareArray[3] = 9;
		compareArray[4] = 2;
		compareArray[5] = 10;
		compareArray[6] = 3;
		compareArray[7] = 11;
		compareArray[8] = 4;
		compareArray[9] = 12;

		buffer.interleaveToFloat32Array(targetArray, 0, 0, 5);
		assertEqualsFloat32Array(compareArray, targetArray);
	}

	function test_interleaveToFloat32Array_sourceOffset() {
		final view0 = buffer.getChannelView(0);
		final view1 = buffer.getChannelView(1);

		// Fill views one after each other
		for (i in 0...buffer.channelLength) {
			view0[i] = i;
		}
		for (i in 0...buffer.channelLength) {
			view1[i] = 8 + i;
		}

		final targetArray = new Float32Array(32);
		clearBuffer(targetArray);

		final compareArray = new Float32Array(32);
		clearBuffer(compareArray);
		compareArray[0] = 2;
		compareArray[1] = 10;
		compareArray[2] = 3;
		compareArray[3] = 11;
		compareArray[4] = 4;
		compareArray[5] = 12;
		compareArray[6] = 5;
		compareArray[7] = 13;
		compareArray[8] = 6;
		compareArray[9] = 14;
		compareArray[10] = 7;
		compareArray[11] = 15;

		buffer.interleaveToFloat32Array(targetArray, 2, 0, 6);
		assertEqualsFloat32Array(compareArray, targetArray);
	}

	function test_interleaveToFloat32Array_targetOffset() {
		final view0 = buffer.getChannelView(0);
		final view1 = buffer.getChannelView(1);

		// Fill views one after each other
		for (i in 0...buffer.channelLength) {
			view0[i] = i;
		}
		for (i in 0...buffer.channelLength) {
			view1[i] = 8 + i;
		}

		final targetArray = new Float32Array(32);
		clearBuffer(targetArray);

		final compareArray = new Float32Array(32);
		clearBuffer(compareArray);
		compareArray[10] = 0;
		compareArray[11] = 8;
		compareArray[12] = 1;
		compareArray[13] = 9;
		compareArray[14] = 2;
		compareArray[15] = 10;
		compareArray[16] = 3;
		compareArray[17] = 11;
		compareArray[18] = 4;
		compareArray[19] = 12;
		compareArray[20] = 5;
		compareArray[21] = 13;
		compareArray[22] = 6;
		compareArray[23] = 14;
		compareArray[24] = 7;
		compareArray[25] = 15;

		buffer.interleaveToFloat32Array(targetArray, 0, 10, 8);
		assertEqualsFloat32Array(compareArray, targetArray);
	}

	function test_test_deinterleaveFromFloat32Array_assertionIfSourceArrayTooSmall() {
		final array = new Float32Array(15);

		assertRaisesAssertion(() -> {
			buffer.deinterleaveFromFloat32Array(array, 2);
		});
	}

	function test_test_deinterleaveFromFloat32Array_assertionIfNumSourceChannelsNegative() {
		final array = new Float32Array(16);

		assertRaisesAssertion(() -> {
			buffer.deinterleaveFromFloat32Array(array, -1);
		});
	}

	function test_test_deinterleaveFromFloat32Array_assertionIfMoreSourceChannelsThanBufferChannels() {
		final array = new Float32Array(32);

		assertRaisesAssertion(() -> {
			buffer.deinterleaveFromFloat32Array(array, 3);
		});
	}

	function test_deinterleaveFromFloat32Array_oneChannelOnly() {
		buffer.clear();

		final sourceArray = new Float32Array(8);
		for (i in 0...sourceArray.length) {
			sourceArray[i] = 2 + i;
		}

		final compareArrayLeft = new Float32Array(8);
		compareArrayLeft[0] = 2;
		compareArrayLeft[1] = 3;
		compareArrayLeft[2] = 4;
		compareArrayLeft[3] = 5;
		compareArrayLeft[4] = 6;
		compareArrayLeft[5] = 7;
		compareArrayLeft[6] = 8;
		compareArrayLeft[7] = 9;

		final compareArrayRight = new Float32Array(8);
		clearBuffer(compareArrayRight);

		buffer.deinterleaveFromFloat32Array(sourceArray, 1);

		assertEqualsFloat32Array(compareArrayLeft, buffer.getChannelView(0));
		assertEqualsFloat32Array(compareArrayRight, buffer.getChannelView(1));
	}

	function test_deinterleaveFromFloat32Array_allChannels() {
		buffer.clear();

		final sourceArray = new Float32Array(16);
		for (i in 0...8) {
			sourceArray[2 * i] = 2 + i;
			sourceArray[2 * i + 1] = -1 - i;
		}

		final compareArrayLeft = new Float32Array(8);
		compareArrayLeft[0] = 2;
		compareArrayLeft[1] = 3;
		compareArrayLeft[2] = 4;
		compareArrayLeft[3] = 5;
		compareArrayLeft[4] = 6;
		compareArrayLeft[5] = 7;
		compareArrayLeft[6] = 8;
		compareArrayLeft[7] = 9;

		final compareArrayRight = new Float32Array(8);
		compareArrayRight[0] = -1;
		compareArrayRight[1] = -2;
		compareArrayRight[2] = -3;
		compareArrayRight[3] = -4;
		compareArrayRight[4] = -5;
		compareArrayRight[5] = -6;
		compareArrayRight[6] = -7;
		compareArrayRight[7] = -8;

		buffer.deinterleaveFromFloat32Array(sourceArray, 2);

		assertEqualsFloat32Array(compareArrayLeft, buffer.getChannelView(0));
		assertEqualsFloat32Array(compareArrayRight, buffer.getChannelView(1));
	}
}
