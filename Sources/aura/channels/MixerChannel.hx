package aura.channels;

import haxe.ds.Vector;

#if cpp
import sys.thread.Mutex;
#end

import kha.FastFloat;
import kha.arrays.Float32Array;

import aura.dsp.DSP;
import aura.utils.BufferUtils.clearBuffer;

/**
	A channel that mixes together the output of multiple input channels.
**/
class MixerChannel extends AudioChannel {
	#if cpp
	static var mutex: Mutex = new Mutex();
	#end

	/**
		The amount of inputs a MixerChannel can hold. Set this value via
		`Aura.init(channelSize)`.
	**/
	static var channelSize: Int;

	public var initialVolume(default, null): FastFloat;

	var inputChannels: Vector<AudioChannel>;

	/**
		Temporary copy of inputChannels for thread safety.
	**/
	var inputChannelsCopy: Vector<AudioChannel>;

	var inserts: Array<DSP> = [];

	public function new(channel: ResamplingAudioChannel = null) {
		inputChannels = new Vector<AudioChannel>(channelSize);

		// this.initialVolume = channel.volume;
	}

	/**
		Adds an input channel. Returns `true` if adding the channel was
		successful, `false` if the amount of input channels is already maxed
		out.
	**/
	public function addInputChannel(channel: AudioChannel): Bool {
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

	public function removeInputChannel(channel: AudioChannel) {
		#if cpp
		mutex.acquire();
		#end

		for (i in 0...MixerChannel.channelSize) {
			if (inputChannels[i] == channel) { // || inputChannels[i].finished) {
				inputChannels[i] = null;
				break;
			}
		}

		#if cpp
		mutex.release();
		#end
	}

	public inline function addInsert(insert: DSP): DSP {
		inserts.push(insert);
		return insert;
	}

	public inline function removeInsert(insert: DSP) {
		inserts.remove(insert);
	}

	public inline function processInserts(buffer: Float32Array, bufferLength: Int) {
		for (insert in inserts) {
			insert.process(buffer, bufferLength);
		}
	}


	public function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void {
		var sampleCacheIndividual = Aura.getSampleCache(treeLevel, requestedLength);

		if (sampleCacheIndividual == null) {
			clearBuffer(requestedSamples, requestedLength);
			return;
		}

		// Copy references to channels for thread safety
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
			if (channel == null) { // || channel.finished) {
				continue;
			}

			channel.nextSamples(sampleCacheIndividual, requestedLength, sampleRate);

			for (i in 0...requestedLength) {
				requestedSamples[i] += sampleCacheIndividual[i] * channel.volume;
			}
		}
		// for (channel in internalStreamChannels) {
		// 	if (channel == null || channel.finished)
		// 		continue;
		// 	channel.nextSamples(sampleCacheIndividual, samples, buffer.samplesPerSecond);
		// 	for (i in 0...samples) {
		// 		sampleCacheAccumulated[i] += sampleCacheIndividual[i] * channel.volume;
		// 	}
		// }

		processInserts(requestedSamples, requestedLength);
	}

	// TODO: Bubble down to individual channels
	public function play(): Void {}
	public function pause(): Void {}
	public function stop(): Void {}
}
