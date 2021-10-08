package aura.format;

import haxe.Int64;
import haxe.io.Input;

inline function readInt64(inp: Input): Int64 {
	final first = inp.readInt32();
	final second = inp.readInt32();

	return inp.bigEndian ? Int64.make(first, second) : Int64.make(second, first);
}

inline function readUInt32(inp: Input): Int64 {
	var out: Int64 = 0;

	for (i in 0...4) {
		out += Int64.shl(inp.readByte(), (inp.bigEndian ? 3 - i : i) * 8);
	}

	return out;
}
