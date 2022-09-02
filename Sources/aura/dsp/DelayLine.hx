package aura.dsp;

import haxe.ds.Vector;

import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.CircularBuffer;

class DelayLine extends DSP {
	public static inline var NUM_CHANNELS = 2;

	public final maxDelaySamples: Int;

	final delayBufs: Vector<CircularBuffer>;

	public function new(maxDelaySamples: Int) {
		this.maxDelaySamples = maxDelaySamples;

		delayBufs = new Vector(NUM_CHANNELS);
		for (i in 0...NUM_CHANNELS) {
			delayBufs[i] = new CircularBuffer(maxDelaySamples);
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

	function process(buffer: AudioBuffer, bufferLength: Int) {
		for (c in 0...buffer.numChannels) {
			final delayBuf = delayBufs[c];
			if (delayBuf.delay == 0) continue;

			final channelView = buffer.getChannelView(c);

			for (i in 0...buffer.channelLength) {
				delayBuf.set(channelView[i]);
				channelView[i] = delayBuf.get();
				delayBuf.increment();
			}
		}
	}

	override function parseMessage(message: DSPMessage) {
		switch (message.id: DSPMessageID) {
			case SetDelays:
				setDelays(message.data);

			default:
				super.parseMessage(message);
		}
	}
}
