package aura.channels;

import aura.dsp.DSP;
import aura.threading.Fifo;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.Interpolator.LinearInterpolator;

/**
	Base class of all audio channels in the audio thread.
**/
@:allow(aura.Aura)
@:access(aura.dsp.DSP)
@:allow(aura.dsp.panner.Panner)
abstract class BaseChannel {
	final messages: Fifo<ChannelMessage> = new Fifo();

	final inserts: Array<DSP> = [];

	// Parameters
	final pVolume = new LinearInterpolator(1.0);
	final pBalance = new LinearInterpolator(Balance.CENTER);
	final pDopplerRatio = new LinearInterpolator(1.0);
	final pDstAttenuation = new LinearInterpolator(1.0);

	var treeLevel(default, null): Int = 0;

	var paused: Bool = false;
	var finished: Bool = true;

	abstract function nextSamples(requestedSamples: AudioBuffer, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(retrigger: Bool): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;

	function isPlayable(): Bool {
		return !paused && !finished;
	}

	function setTreeLevel(level: Int) {
		this.treeLevel = level;
	}

	inline function processInserts(buffer: AudioBuffer, bufferLength: Int) {
		for (insert in inserts) {
			if (insert.bypass) { continue; }
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

	function synchronize() {
		var message: Null<ChannelMessage>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}

		for (insert in inserts) {
			insert.synchronize();
		}
	}

	function parseMessage(message: ChannelMessage) {
		switch (message.id) {
			case Play: play(cast message.data);
			case Pause: pause();
			case Stop: stop();

			case PVolume: pVolume.targetValue = cast message.data;
			case PBalance: pBalance.targetValue = cast message.data;
			case PDopplerRatio: pDopplerRatio.targetValue = cast message.data;
			case PDstAttenuation: pDstAttenuation.targetValue = cast message.data;

			default:
		}
	}

	inline function sendMessage(message: ChannelMessage) {
		messages.push(message);
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
