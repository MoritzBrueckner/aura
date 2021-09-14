package aura;

import aura.channels.MixChannel;

/**
	Main-thread handle to a `MixChannel` in the audio thread.
**/
class MixChannelHandle extends Handle {

	/**
		Adds an input channel. Returns `true` if adding the channel was
		successful, `false` if the amount of input channels is already maxed
		out.
	**/
	public inline function addInputChannel(channelHandle: Handle): Bool {
		assert(Error, channelHandle != null, "channelHandle must not be null");
		return getMixChannel().addInputChannel(channelHandle.channel);
	}

	/**
		Removes an input channel from this `MixChannel`.
	**/
	public inline function removeInputChannel(channelHandle: Handle) {
		getMixChannel().removeInputChannel(channelHandle.channel);
	}

	inline function getMixChannel(): MixChannel {
		return cast this.channel;
	}
}
