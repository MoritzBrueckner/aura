package aura.channels;

import haxe.ds.Vector;

#if cpp
import sys.thread.Mutex;
#end

import kha.FastFloat;
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

	public var initialVolume(default, null): FastFloat;

	var inputChannels: Vector<BaseChannel>;

	/**
		Temporary copy of inputChannels for thread safety.
	**/
	var inputChannelsCopy: Vector<BaseChannel>;

	public function new(channel: ResamplingAudioChannel = null) {
		inputChannels = new Vector<BaseChannel>(channelSize);

		// this.initialVolume = channel.volume;
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

		#if cpp
		mutex.release();
		#end
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
		final sampleCacheIndividual = Aura.getSampleCache(treeLevel, requestedLength);

		if (sampleCacheIndividual == null) {
			clearBuffer(requestedSamples, requestedLength);
			return;
		}

		// Copy references to channels for thread safety
		// TODO: Move this out of this callback!
		#if cpp
		mutex.acquire();
		#end
		inputChannelsCopy = inputChannels.copy();

		// TODO: Streaming
		// for (i in 0...channelCount) {
		// 	internalStreamChannels[i] = streamChannels[i];
		// }
		#if cpp
		mutex.release();
		#end

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

		final stepVol = pVolume.getLerpStepSize(requestedLength);
		for (i in 0...requestedLength) {
			requestedSamples[i] *= pVolume.currentValue;
			pVolume.currentValue += stepVol;
		}

		pVolume.updateLast();

		processInserts(requestedSamples, requestedLength);
	}

	// TODO: Bubble down to individual channels
	public function play(): Void {}
	public function pause(): Void {}
	public function stop(): Void {}
}
