package aura.dsp;

import kha.arrays.Float32Array;

interface DSP {
	function process(buffer: Float32Array, bufferLength: Int): Void;
}
