package auratests.format;

import haxe.Int64;
import haxe.io.Bytes;
import haxe.io.BytesInput;

import utest.Assert;

using aura.format.InputExtension;

class TestInputExtension extends utest.Test {
	var bytes: Bytes;
	var inp: BytesInput;

	// 10000000 01000000 00100000 00010000 - 00001000 00000100 00000010 00000001
	var inputValue = Int64.make(
		1 << 31 | 1 << 22 | 1 << 13 | 1 << 4,
		1 << 27 | 1 << 18 | 1 << 9 | 1
	);

	// 00000001 00000010 00000100 00001000 - 00010000 00100000 01000000 10000000
	var inputValueInverted = Int64.make(
		1 << 24 | 1 << 17 | 1 << 10 | 1 << 3,
		1 << 28 | 1 << 21 | 1 << 14 | 1 << 7
	);

	function setup() {
		bytes = Bytes.alloc(8);
		inp = new BytesInput(bytes);
	}

	function test_readInt64_littleEndian_correctRead() {
		bytes.setInt64(0, inputValue); // setInt64 is little-endian
		inp.bigEndian = false;
		assertI64Equals(inputValue, inp.readInt64());
	}

	function test_readInt64_bigEndian_correctRead() {
		bytes.setInt64(0, inputValue);
		inp.bigEndian = true;
		assertI64Equals(inputValueInverted, inp.readInt64());
	}

	function test_readUint32_isUnsigned() {
		bytes.setInt32(0, 1 << 31);
		inp.bigEndian = false;
		assertI64Equals(Int64.make(0, -2147483648/* -2^31, sign bit doesn't mean anything in low part */) , inp.readUInt32());
	}

	function test_readUint32_littleEndian_correctRead() {
		bytes.setInt32(0, inputValue.high);
		inp.bigEndian = false;
		assertI64Equals(Int64.make(0, inputValue.high), inp.readUInt32());
	}

	function test_readUint32_bigEndian_correctRead() {
		bytes.setInt32(0, inputValue.high);
		inp.bigEndian = true;
		assertI64Equals(Int64.make(0, inputValueInverted.low), inp.readUInt32());
	}

	function assertI64Equals(want: Int64, have: Int64, ?pos: haxe.PosInfos) {
		final errorMessage = 'Expected (high: ${want.high}, low: ${want.low}), have (high: ${have.high}, low: ${have.low}).';
		Assert.isTrue(want.low == have.low && want.high == have.high, errorMessage, pos);
	}
}
