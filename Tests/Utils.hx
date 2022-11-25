package;

import aura.Handle;
import aura.channels.AudioChannel;

inline function createDummyHandle(): Handle {
	final data = new kha.arrays.Float32Array(8);
	final channel = new AudioChannel(data, false);
	return new Handle(channel);
}

inline function int32ToBytesString(i: Int): String {
	var str = "";
	for (j in 0...32) {
		final mask = 1 << (31 - j);
		str += (i & mask) == 0 ? "0" : "1";
	}
	return str;
}
