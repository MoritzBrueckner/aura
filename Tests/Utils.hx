package;

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
