package aura.dsp;

import kha.arrays.Float32Array;

/**
 * Random signal with a constant power spectral density.
 */
class WhiteNoise implements DSP {

    var inUse = false;

    public inline function new() {
    }

    public function process(buffer: Float32Array, bufferLength: Int) {
        for( i in 0...bufferLength )
            buffer[i] = Math.random() * 2 - 1;
    }

}
