package aura.dsp;

import kha.arrays.Float32Array;

abstract class DSP {
	var inUse: Bool;

	abstract function process(buffer: Float32Array, bufferLength: Int): Void;
}
