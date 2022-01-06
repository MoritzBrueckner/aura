package aura.dsp;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.threading.Message.DSPMessage;
import aura.utils.CircularBuffer;

class DelayLine extends DSP {
	public static inline var NUM_CHANNELS = 2;

	public final maxDelaySamples: Int;

	final delayBufs: Vector<CircularBuffer<Float>>;

	public function new(maxDelaySamples: Int) {
		this.maxDelaySamples = maxDelaySamples;

		delayBufs = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			delayBufs[i] = new CircularBuffer<Float>(maxDelaySamples);
		}
	}

	public inline function setDelay(delaySamples: Int) {
		for (i in 0...NUM_CHANNELS) {
			delayBufs[i].setDelay(delaySamples);
		}
	}

	public inline function setDelays(delaySamples: Array<Int>) {
		for (i in 0...NUM_CHANNELS) {
			delayBufs[i].setDelay(delaySamples[i]);
		}
	}

	function process(buffer: Float32Array, bufferLength: Int) {
		for (c in 0...NUM_CHANNELS) {
			if (delayBufs[c].delay == 0) continue;

			final deinterleavedLength = Std.int(bufferLength / NUM_CHANNELS);
			for (i in 0...deinterleavedLength) {
				delayBufs[c].set(buffer[i * NUM_CHANNELS + c]);
				buffer[i * NUM_CHANNELS + c] = delayBufs[c].get();
				delayBufs[c].increment();
			}
		}
	}

	override function parseMessage(message: DSPMessage) {
		switch (message.id) {
			case SetDelays:
				setDelays(message.data);

			default:
				super.parseMessage(message);
		}
	}
}
