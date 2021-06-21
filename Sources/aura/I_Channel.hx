package aura;

import kha.arrays.Float32Array;

import aura.dsp.DSP;

interface I_Channel {
	function addInsert(insert: DSP): DSP;
	function removeInsert(insert: DSP): Void;

	function processInserts(buffer: Float32Array, bufferLength: Int): Void;
}
