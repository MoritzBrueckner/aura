package aura.channels;

import kha.arrays.Float32Array;

import aura.Message;
import aura.dsp.DSP;
import aura.utils.Fifo;
import aura.utils.Interpolator.LinearInterpolator;

/**
	Base class of all audio channels in the audio thread.
**/
abstract class BaseChannel {
	final messages: Fifo<Message> = new Fifo();

	var treeLevel: Int = 0;
	var inserts: Array<DSP> = [];

	var paused: Bool = false;
	var finished: Bool = false;

	// Parameters
	var pVolume = new LinearInterpolator(1.0);
	var pBalance = new LinearInterpolator(Balance.CENTER);
	var pDopplerRatio = new LinearInterpolator(1.0);
	var pDstAttenuation = new LinearInterpolator(1.0);

	abstract function synchronize(): Void;
	public abstract function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;

	inline function isPlayable(): Bool {
		return !paused && !finished;
	}

	inline function processInserts(buffer: Float32Array, bufferLength: Int) {
		for (insert in inserts) {
			insert.process(buffer, bufferLength);
		}
	}

	inline function parseMessage(message: Message) {
		switch (message.id) {
			case Play: play();
			case Pause: pause();
			case Stop: stop();

			case PVolume: pVolume.targetValue = cast message.data;
			case PBalance: pBalance.targetValue = cast message.data;
			case PDopplerRatio: pDopplerRatio.targetValue = cast message.data;
			case PDstAttenuation: pDstAttenuation.targetValue = cast message.data;

			default:
		}
	}

	inline function sendMessage(message: Message) {
		messages.push(message);
	}

	inline function tryPopMessage(): Null<Message> {
		return messages.tryPop();
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}