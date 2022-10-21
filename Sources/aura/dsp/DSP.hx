package aura.dsp;

import aura.threading.Fifo;
import aura.threading.Message;
import aura.types.AudioBuffer;

@:allow(aura.dsp.panner.Panner)
abstract class DSP {
	public var bypass: Bool;

	var inUse: Bool;
	final messages: Fifo<Message> = new Fifo();

	abstract function process(buffer: AudioBuffer): Void;

	function synchronize() {
		var message: Null<Message>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}
	}

	function parseMessage(message: Message) {
		switch (message.id) {
			// TODO
			case DSPMessageID.BypassEnable:
			case DSPMessageID.BypassDisable:

			default:
		}
	}

	inline function sendMessage(message: Message) {
		messages.add(message);
	}
}
