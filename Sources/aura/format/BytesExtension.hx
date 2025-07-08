package aura.format;

import haxe.io.Bytes;

using StringTools;

/**
	Variant of `aura.format.InputExtension.isByteMagic()` for `haxe.io.Bytes`.
**/
inline function isByteMagic(bytes: Bytes, position: Int, magicASCII: String): Bool {
	var match = true;
	for (i in 0...magicASCII.length) {
		match = match && bytes.get(position + i) == magicASCII.fastCodeAt(i);
	}

	return match;
}
