package aura.dsp;

import aura.threading.Fifo;
import aura.threading.Message;
import aura.types.AudioBuffer;

@:allow(aura.dsp.panner.Panner)
abstract class DSP {
	public var bypass: Bool;

	var inUse: Bool;
	final messages: Fifo<DSPMessage> = new Fifo();

	abstract function process(buffer: AudioBuffer, bufferLength: Int): Void;

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
		messages.add(message);
	}
}
