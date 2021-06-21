package aura;

import kha.FastFloat;
import kha.arrays.Float32Array;

inline function fillBuffer(buffer: Float32Array, value: FastFloat, length: Int = -1) {
	for (i in 0...(length == -1 ? buffer.length : length)) {
		buffer[i] = value;
	}
}

inline function clearBuffer(buffer: Float32Array, length: Int = -1) {
	fillBuffer(buffer, 0, length);
}
