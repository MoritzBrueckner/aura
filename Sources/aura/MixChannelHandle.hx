package aura;

import aura.channels.MixChannel;

#if AURA_DEBUG
using aura.utils.MapExtension;
#end

/**
	Main-thread handle to a `MixChannel` in the audio thread.
**/
class MixChannelHandle extends Handle {
	#if AURA_DEBUG
	public var name: String = "";
	public var inputHandles: Array<Handle> = new Array();
	#end

	/**
		Adds an input channel. Returns `true` if adding the channel was
		successful, `false` if the amount of input channels is already maxed
		out.
	**/
	public inline function addInputChannel(channelHandle: Handle): Bool {
		assert(Error, channelHandle != null, "channelHandle must not be null");
		final foundChannel = getMixChannel().addInputChannel(channelHandle.channel);
	#if AURA_DEBUG
		if (foundChannel) inputHandles.push(channelHandle);
	#end
		return foundChannel;
	}

	/**
		Removes an input channel from this `MixChannel`.
	**/
	public inline function removeInputChannel(channelHandle: Handle) {
	#if AURA_DEBUG
		inputHandles.remove(channelHandle);
	#end
		getMixChannel().removeInputChannel(channelHandle.channel);
	}

	inline function getMixChannel(): MixChannel {
		return cast this.channel;
	}

	#if AURA_DEBUG
	public override function getDebugAttrs(): Map<String, String> {
		return super.getDebugAttrs().mergeIntoThis([
			"Name" => name,
			"Num inserts" => Std.string(@:privateAccess channel.inserts.length),
		]);
	}
	#end
}
