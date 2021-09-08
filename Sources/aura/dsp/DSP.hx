package aura.dsp;

import kha.arrays.Float32Array;

interface DSP {
	private var inUse: Bool;

	function process(buffer: Float32Array, bufferLength: Int): Void;
}
