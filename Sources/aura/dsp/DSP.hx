package aura.dsp;

import kha.arrays.Float32Array;

import aura.threading.Fifo;
import aura.threading.Message;

abstract class DSP {
	public var bypass: Bool;

	var inUse: Bool;
	final messages: Fifo<DSPMessage> = new Fifo();

	abstract function process(buffer: Float32Array, bufferLength: Int): Void;

	function synchronize() {
		var message: Null<DSPMessage>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}
	}

	function parseMessage(message: DSPMessage) {
		switch (message.id) {
			// TODO
			case BypassEnable:
			case BypassDisable:

			default:
		}
	}

	inline function sendMessage(message: DSPMessage) {
		messages.push(message);
	}
}
