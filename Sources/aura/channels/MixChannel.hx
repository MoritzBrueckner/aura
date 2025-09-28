package aura.channels;

import haxe.ds.Vector;

#if cpp
import sys.thread.Mutex;
#end

#if (kha_html5 || kha_debug_html5)
import aura.Aura;
import js.html.audio.AudioContext;
#end

import aura.channels.BaseChannel.BaseChannelHandle;
import aura.threading.BufferCache;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.Profiler;


/**
	Main-thread handle to a `MixChannel` in the audio thread.
**/
class MixChannelHandle extends BaseChannelHandle {
	#if AURA_DEBUG
	public var name: String = "";
	public var inputHandles: Array<BaseChannelHandle> = new Array();
	#end

	public inline function getNumInputs(): Int {
		return getMixChannel().getNumInputs();
	}

	/**
		Adds an input channel. Returns `true` if adding the channel was
		successful, `false` if the amount of input channels is already maxed
		out.
	**/
	inline function addInputChannel(channelHandle: BaseChannelHandle): Bool {
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
	inline function removeInputChannel(channelHandle: BaseChannelHandle) {
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


/**
	A channel that mixes together the output of multiple input channels.
**/
@:access(aura.dsp.DSP)
class MixChannel extends BaseChannel {
	#if cpp
	static var mutex: Mutex = new Mutex();
	#end

	/**
		The amount of inputs a MixChannel can hold. Set this value via
		`Aura.init(channelSize)`.
	**/
	static var channelSize: Int;

	var inputChannels: Vector<BaseChannel>;
	var numUsedInputs: Int = 0;

	/**
		Temporary copy of inputChannels for thread safety.
	**/
	var inputChannelsCopy: Vector<BaseChannel>;

	#if (kha_html5 || kha_debug_html5)
	var audioContext: AudioContext;
	#end

	public function new() {
		#if (kha_html5 || kha_debug_html5)
		audioContext = Aura.audioContext;
		gain = audioContext.createGain();
		gain.connect(audioContext.destination);
		#end

		inputChannels = new Vector<BaseChannel>(channelSize);

		// Make sure super.isPlayable() is true until we find better semantics
		// for MixChannel.play()/pause()/stop()
		this.finished = false;
	}

	/**
		Adds an input channel. Returns `true` if adding the channel was
		successful, `false` if the amount of input channels is already maxed
		out.
	**/
	public function addInputChannel(channel: BaseChannel): Bool {
		var foundChannel = false;

		#if cpp
		mutex.acquire();
		#end

		for (i in 0...MixChannel.channelSize) {
			if (inputChannels[i] == null) { // || inputChannels[i].finished) {
				inputChannels[i] = channel;
				numUsedInputs++;
				channel.setTreeLevel(this.treeLevel + 1);

				foundChannel = true;
				break;
			}
		}

		updateChannelsCopy();

		#if cpp
		mutex.release();
		#end

		return foundChannel;
	}

	public function removeInputChannel(channel: BaseChannel) {
		#if cpp
		mutex.acquire();
		#end

		for (i in 0...MixChannel.channelSize) {
			if (inputChannels[i] == channel) {
				inputChannels[i] = null;
				numUsedInputs--;
				break;
			}
		}

		updateChannelsCopy();

		#if cpp
		mutex.release();
		#end
	}

	public inline function getNumInputs() {
		return numUsedInputs;
	}

	/**
		Copy the references to the inputs channels for thread safety. This
		function does not acquire any additional mutexes.
		@see `MixChannel.inputChannelsCopy`
	**/
	inline function updateChannelsCopy() {
		inputChannelsCopy = inputChannels.copy();

		// TODO: Streaming
		// for (i in 0...channelCount) {
		// 	internalStreamChannels[i] = streamChannels[i];
		// }
	}

	override function isPlayable(): Bool {
		// TODO: be more intelligent here and actually check inputs?
		return super.isPlayable() && numUsedInputs != 0;
	}

	override function setTreeLevel(level: Int) {
		this.treeLevel = level;
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.setTreeLevel(level + 1);
			}
		}
	}

	override function synchronize() {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.synchronize();
			}
		}
		super.synchronize();
	}

	function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz): Void {
		Profiler.event();

		if (numUsedInputs == 0) {
			requestedSamples.clear();
			return;
		}

		final inputBuffer = BufferCache.getTreeBuffer(treeLevel, requestedSamples.numChannels, requestedSamples.channelLength);
		if (inputBuffer == null) {
			requestedSamples.clear();
			return;
		}

		var first = true;
		var foundPlayableInput = false;
		for (channel in inputChannelsCopy) {
			if (channel == null || !channel.isPlayable()) {
				continue;
			}
			foundPlayableInput = true;

			channel.nextSamples(inputBuffer, sampleRate);

			if (first) {
				// To prevent feedback loops, the input buffer has to be cleared
				// before all inputs are added to it. To not waste calculations,
				// we do not clear the buffer here but instead just override
				// the previous sample cache.
				for (i in 0...requestedSamples.rawData.length) {
					requestedSamples.rawData[i] = inputBuffer.rawData[i];
				}
				first = false;
			}
			else {
				for (i in 0...requestedSamples.rawData.length) {
					requestedSamples.rawData[i] += inputBuffer.rawData[i];
				}
			}
		}

		// for (channel in internalStreamChannels) {
		// 	if (channel == null || !channel.isPlayable())
		// 		continue;
		// 	foundPlayableInput = true;
		// 	channel.nextSamples(inputBuffer, samples, buffer.samplesPerSecond);
		// 	for (i in 0...samples) {
		// 		sampleCacheAccumulated[i] += inputBuffer[i] * channel.volume;
		// 	}
		// }

		if (!foundPlayableInput) {
			// Didn't read from input channels, clear possible garbage values
			requestedSamples.clear();
			return;
		}

		// Apply volume of this channel
		final stepVol = pVolume.getLerpStepSize(requestedSamples.channelLength);
		for (c in 0...requestedSamples.numChannels) {
			final channelView = requestedSamples.getChannelView(c);

			for (i in 0...requestedSamples.channelLength) {
				channelView[i] *= pVolume.currentValue;
				pVolume.currentValue += stepVol;
			}
			pVolume.currentValue = pVolume.lastValue;
		}

		pVolume.updateLast();

		processInserts(requestedSamples);
	}

	/**
		Calls `play()` for all input channels.
	**/
	public function play(retrigger: Bool): Void {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.play(retrigger);
			}
		}
	}

	/**
		Calls `pause()` for all input channels.
	**/
	public function pause(): Void {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.pause();
			}
		}
	}

	/**
		Calls `stop()` for all input channels.
	**/
	public function stop(): Void {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.stop();
			}
		}
	}

	#if (kha_html5 || kha_debug_html5)
	//TODO: add the rest of the messages for effects or create a separate `Html5MixChannel` class?
	override function parseMessage(message: Message) {
		switch (message.id) {
			// Because we're using a HTML implementation here, we cannot use the
			// LinearInterpolator parameters
			case ChannelMessageID.PVolume: gain.gain.value = cast message.data;

			default:
				super.parseMessage(message);
		}
	}
	#end
}
