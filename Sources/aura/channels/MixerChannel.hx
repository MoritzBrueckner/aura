package aura.channels;

import haxe.ds.Vector;

#if cpp
import sys.thread.Mutex;
#end

import kha.arrays.Float32Array;

import aura.utils.BufferUtils.clearBuffer;

/**
	A channel that mixes together the output of multiple input channels.
**/
class MixerChannel extends BaseChannel {
	#if cpp
	static var mutex: Mutex = new Mutex();
	#end

	/**
		The amount of inputs a MixerChannel can hold. Set this value via
		`Aura.init(channelSize)`.
	**/
	static var channelSize: Int;

	var inputChannels: Vector<BaseChannel>;

	/**
		Temporary copy of inputChannels for thread safety.
	**/
	var inputChannelsCopy: Vector<BaseChannel>;

	public function new(channel: ResamplingAudioChannel = null) {
		inputChannels = new Vector<BaseChannel>(channelSize);
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

		for (i in 0...MixerChannel.channelSize) {
			if (inputChannels[i] == null) { // || inputChannels[i].finished) {
				inputChannels[i] = channel;
				channel.treeLevel = this.treeLevel + 1;

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

		for (i in 0...MixerChannel.channelSize) {
			if (inputChannels[i] == channel) {
				inputChannels[i] = null;
				break;
			}
		}

		updateChannelsCopy();

		#if cpp
		mutex.release();
		#end
	}

	/**
		Copy the references to the inputs channels for thread safety. This
		function does not acquire any additional mutexes.
		@see `MixerChannel.inputChannelsCopy`
	**/
	inline function updateChannelsCopy() {
		inputChannelsCopy = inputChannels.copy();

		// TODO: Streaming
		// for (i in 0...channelCount) {
		// 	internalStreamChannels[i] = streamChannels[i];
		// }
	}

	public function synchronize() {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.synchronize();
			}
		}

		var message: Null<Message>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}
	}

	public function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void {
		// No input channel added yet, skip useless computations
		if (inputChannelsCopy == null) {
			clearBuffer(requestedSamples, requestedLength);
			return;
		}

		final sampleCacheIndividual = Aura.getSampleCache(treeLevel, requestedLength);
		if (sampleCacheIndividual == null) {
			clearBuffer(requestedSamples, requestedLength);
			return;
		}

		for (channel in inputChannelsCopy) {
			if (channel == null || !channel.isPlayable()) {
				continue;
			}

			channel.nextSamples(sampleCacheIndividual, requestedLength, sampleRate);

			for (i in 0...requestedLength) {
				requestedSamples[i] += sampleCacheIndividual[i];
			}
		}
		// for (channel in internalStreamChannels) {
		// 	if (channel == null || !channel.isPlayable())
		// 		continue;
		// 	channel.nextSamples(sampleCacheIndividual, samples, buffer.samplesPerSecond);
		// 	for (i in 0...samples) {
		// 		sampleCacheAccumulated[i] += sampleCacheIndividual[i] * channel.volume;
		// 	}
		// }

		// Apply volume of this channel
		final stepVol = pVolume.getLerpStepSize(requestedLength);
		for (i in 0...requestedLength) {
			requestedSamples[i] *= pVolume.currentValue;
			pVolume.currentValue += stepVol;
		}

		pVolume.updateLast();

		processInserts(requestedSamples, requestedLength);
	}

	/**
		Calls `play()` for all input channels.
	**/
	public function play(): Void {
		for (inputChannel in inputChannels) {
			if (inputChannel != null) {
				inputChannel.play();
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
}
