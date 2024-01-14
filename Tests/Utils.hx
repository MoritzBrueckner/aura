package;

import haxe.PosInfos;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Aura;
import aura.channels.UncompBufferChannel;

inline function createDummyHandle(): BaseChannelHandle {
	final data = new kha.arrays.Float32Array(8);
	final channel = new UncompBufferChannel(data, false);
	return new BaseChannelHandle(channel);
}

inline function int32ToBytesString(i: Int): String {
	var str = "";
	for (j in 0...32) {
		final mask = 1 << (31 - j);
		str += (i & mask) == 0 ? "0" : "1";
	}
	return str;
}

inline function assertRaisesAssertion(func: Void->Void) {
	#if (AURA_ASSERT_LEVEL!="NoAssertions")
		Assert.raises(func, aura.utils.Assert.AuraAssertionException);
	#else
		Assert.pass();
	#end
}

function assertEqualsFloat32Array(expected: Float32Array, have: Float32Array, ?pos: PosInfos) {
	if (expected.length != have.length) {
		Assert.fail('Expected Float32Array of length ${expected.length}, but got length ${have.length}', pos);
		return;
	}

	for (i in 0...expected.length) {
		if (!@:privateAccess Assert._floatEquals(expected[i], have[i])) {
			Assert.fail('Expected value at index $i to be ${expected[i]}, but got ${have[i]} (only first difference reported)', pos);
			return;
		}
	}
	Assert.pass(null, pos);
}
