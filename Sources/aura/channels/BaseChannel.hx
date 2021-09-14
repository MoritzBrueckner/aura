package aura.channels;

import kha.arrays.Float32Array;

import aura.dsp.DSP;
import aura.threading.Fifo;
import aura.threading.Message;
import aura.utils.Interpolator.LinearInterpolator;

/**
	Base class of all audio channels in the audio thread.
**/
@:allow(aura.Aura)
@:access(aura.dsp.DSP)
abstract class BaseChannel {
	final messages: Fifo<Message> = new Fifo();

	final inserts: Array<DSP> = [];

	// Parameters
	final pVolume = new LinearInterpolator(1.0);
	final pBalance = new LinearInterpolator(Balance.CENTER);
	final pDopplerRatio = new LinearInterpolator(1.0);
	final pDstAttenuation = new LinearInterpolator(1.0);

	var treeLevel(default, null): Int = 0;

	var paused: Bool = false;
	var finished: Bool = false;

	abstract function synchronize(): Void;
	abstract function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;

	function isPlayable(): Bool {
		return !paused && !finished;
	}

	function setTreeLevel(level: Int) {
		this.treeLevel = level;
	}

	inline function processInserts(buffer: Float32Array, bufferLength: Int) {
		for (insert in inserts) {
			insert.process(buffer, bufferLength);
		}
	}

	public inline function addInsert(insert: DSP): DSP {
		assert(Critical, !insert.inUse, "DSP objects can only belong to one unique channel");
		insert.inUse = true;
		inserts.push(insert);
		return insert;
	}

	public inline function removeInsert(insert: DSP) {
		var found = inserts.remove(insert);
		if (found) {
			insert.inUse = false;
		}
	}

	function parseMessage(message: Message) {
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
