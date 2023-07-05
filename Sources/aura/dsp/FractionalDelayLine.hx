package aura.dsp;

import haxe.ds.Vector;

import kha.FastFloat;
import kha.arrays.Float32Array;

import aura.Types;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.CircularBuffer;

/**
	A delay line that supports fractions of samples set as delay times.

	The implementation follows the linear interpolation approach as presented
	in https://ccrma.stanford.edu/~jos/pasp/Fractional_Delay_Filtering_Linear.html.

	@see `aura.dsp.DelayLine`
**/
class FractionalDelayLine extends DSP {
	/**
		The maximum amount of channels this DSP effect supports.
	**/
	public final maxNumChannels: Int;

	/**
		The maximum amount of (whole) samples by which any channel of the input
		can be delayed.
	**/
	public final maxDelayLength: Int;

	final delayBufs: Vector<CircularBuffer>;
	final delayLengthFracts: Float32Array;

	public function new(maxNumChannels: Int, maxDelayLength: Int) {
		this.maxNumChannels = maxNumChannels;
		this.maxDelayLength = maxDelayLength;

		delayLengthFracts = new Float32Array(maxNumChannels);
		delayBufs = new Vector(maxNumChannels);
		for (i in 0...maxNumChannels) {
			delayLengthFracts[i] = 0.0;
			delayBufs[i] = new CircularBuffer(maxDelayLength);
		}
	}

	public inline function setDelayLength(channelMask: Channels, delayLength: FastFloat) {
		assert(Error, delayLength >= 0);
		assert(Error, delayLength < maxDelayLength);

		sendMessage({id: DSPMessageID.SetDelays, data: [channelMask, delayLength]});
	}

	function process(buffer: AudioBuffer) {
		for (c in 0...buffer.numChannels) {
			if (delayBufs[c].delay == 0) continue;

			final channelView = buffer.getChannelView(c);

			for (i in 0...buffer.channelLength) {
				delayBufs[c].set(channelView[i]);

				var delayedSignalMm1 = delayBufs[c].get(); // M - 1
				delayBufs[c].increment();
				var delayedSignalM = delayBufs[c].get(); // M

				channelView[i] = delayedSignalM + delayLengthFracts[c] * (delayedSignalMm1 - delayedSignalM);
			}
		}
	}

	override function parseMessage(message: Message) {
		switch (message.id) {
			case DSPMessageID.SetDelays:
				final channelMask = message.dataAsArrayUnsafe()[0];
				final delayLength = message.dataAsArrayUnsafe()[1];
				at_setDelayLength(channelMask, delayLength);

			default:
				super.parseMessage(message);
		}
	}

	inline function at_setDelayLength(channelMask: Channels, delayLength: FastFloat) {
		final delayLengthFloor = Math.ffloor(delayLength); // TODO implement 32-bit ffloor
		final delayLengthFract = delayLength - delayLengthFloor;
		final delayLengthInt = Std.int(delayLengthFloor);

		for (c in 0...maxNumChannels) {
			if (!channelMask.matchesIndex(c)) {
				continue;
			}

			delayLengthFracts[c] = delayLengthFract;
			delayBufs[c].setDelay(delayLengthInt + 1);
		}
	}
}
