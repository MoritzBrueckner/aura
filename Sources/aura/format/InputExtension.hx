package aura.format;

import haxe.Int64;
import haxe.io.Input;

using StringTools;

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

/**
	Platform- and encoding-independent way of matching the input with an ASCII
	magic string. This function does not consider the input endianess, it is
	assumed that the order of characters in `magicASCII` matches the byte order
	in the input stream.

	- `inp.readString(len, haxe.io.Encoding.UTF8)` does not work if the input
	streams contains data that can be interpreted as multi-byte characters.

	- `inp.readString(len, haxe.io.Encoding.RawNative)` does not yield
	platform-indepent results.
**/
inline function isByteMagic(inp: Input, magicASCII: String): Bool {
	var match = true;
	for (i in 0...magicASCII.length) {
		match = match && inp.readByte() == magicASCII.fastCodeAt(i);
	}

	return match;
}
