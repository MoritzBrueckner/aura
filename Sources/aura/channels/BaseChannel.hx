package aura.channels;

import aura.channels.MixChannel.MixChannelHandle;
import aura.dsp.DSP;
import aura.dsp.panner.Panner;
import aura.threading.Fifo;
import aura.threading.Message;
import aura.types.AudioBuffer;
import aura.utils.Interpolator.LinearInterpolator;
import aura.utils.MathUtils;

/**
	Main-thread handle to an audio channel in the audio thread.
**/
@:access(aura.channels.BaseChannel)
@:allow(aura.dsp.panner.Panner)
class BaseChannelHandle {
	/**
		Whether the playback of the handle's channel is currently paused.
	**/
	public var paused(get, never): Bool;
	inline function get_paused(): Bool { return channel.paused; }

	/**
		Whether the playback of the handle's channel has finished.
		On `MixerChannel`s this value is always `false`.
	**/
	public var finished(get, never): Bool;
	inline function get_finished(): Bool { return channel.finished; }

	public var panner(get, null): Null<Panner>;
	inline function get_panner(): Null<Panner> { return channel.panner; }

	/**
		Link to the audio channel in the audio thread.
	**/
	final channel: BaseChannel;
	var parentHandle: Null<MixChannelHandle> = null;

	// Parameter cache for getter functions
	var _volume: Float = 1.0;
	var _pitch: Float = 1.0;

	public inline function new(channel: BaseChannel) {
		this.channel = channel;
	}

	/**
		Starts the playback. If the sound wasn't played before or was stopped,
		the playback starts from the beginning. If it is paused, playback starts
		from the position where it was paused.

		@param retrigger Controls the behaviour if the sound is already playing.
			If true, restart playback from the beginning, else do nothing.
	**/
	public inline function play(retrigger = false) {
		channel.sendMessage({ id: ChannelMessageID.Play, data: retrigger });
	}

	public inline function pause() {
		channel.sendMessage({ id: ChannelMessageID.Pause, data: null });
	}

	public inline function stop() {
		channel.sendMessage({ id: ChannelMessageID.Stop, data: null });
	}

	public inline function addInsert(insert: DSP): DSP {
		return channel.addInsert(insert);
	}

	public inline function removeInsert(insert: DSP) {
		channel.removeInsert(insert);
	}

	/**
		Set the mix channel into which this channel routes its output.
		Returns `true` if setting the mix channel was successful and `false` if
		there would be a circular dependency or the amount of input channels of
		the mix channel is already maxed out.
	**/
	public function setMixChannel(mixChannelHandle: MixChannelHandle): Bool {
		if (mixChannelHandle == parentHandle) {
			return true;
		}

		if (parentHandle != null) {
			@:privateAccess parentHandle.removeInputChannel(this);
			parentHandle = null;
		}

		if (mixChannelHandle == null) {
			return true;
		}

		// Return false for circular references (including mixChannelHandle == this)
		var curHandle = mixChannelHandle;
		while (curHandle != null) {
			if (curHandle == this) {
				return false;
			}
			curHandle = curHandle.parentHandle;
		}

		final success = @:privateAccess mixChannelHandle.addInputChannel(this);
		if (success) {
			parentHandle = mixChannelHandle;
		} else {
			parentHandle = null;
		}

		return success;
	}

	public inline function setVolume(volume: Float) {
		assert(Critical, volume >= 0, "Volume value must not be a negative number!");

		channel.sendMessage({ id: ChannelMessageID.PVolume, data: maxF(0.0, volume) });
		this._volume = volume;
	}

	public inline function getVolume(): Float {
		return this._volume;
	}

	public inline function setPitch(pitch: Float) {
		assert(Critical, pitch > 0, "Pitch value must be a positive number!");

		channel.sendMessage({ id: ChannelMessageID.PPitch, data: maxF(0.0, pitch) });
		this._pitch = pitch;
	}

	public inline function getPitch(): Float {
		return this._pitch;
	}

	#if AURA_DEBUG
	public function getDebugAttrs(): Map<String, String> {
		return ["In use" => Std.string(@:privateAccess channel.isPlayable())];
	}
	#end
}

/**
	Base class of all audio channels in the audio thread.
**/
@:allow(aura.Aura)
@:access(aura.dsp.DSP)
@:allow(aura.dsp.panner.Panner)
@:access(aura.dsp.panner.Panner)
abstract class BaseChannel {
	final messages: Fifo<Message> = new Fifo();

	final inserts: Array<DSP> = [];
	var panner: Null<Panner> = null;

	// Parameters
	final pVolume = new LinearInterpolator(1.0);
	final pDopplerRatio = new LinearInterpolator(1.0);
	final pDstAttenuation = new LinearInterpolator(1.0);

	var treeLevel(default, null): Int = 0;

	var paused: Bool = false;
	var finished: Bool = true;

	abstract function nextSamples(requestedSamples: AudioBuffer, sampleRate: Hertz): Void;

	abstract function play(retrigger: Bool): Void;
	abstract function pause(): Void;
	abstract function stop(): Void;

	function isPlayable(): Bool {
		return !paused && !finished;
	}

	function setTreeLevel(level: Int) {
		this.treeLevel = level;
	}

	inline function processInserts(buffer: AudioBuffer) {
		for (insert in inserts) {
			if (insert.bypass) { continue; }
			insert.process(buffer);
		}

		if (panner != null) {
			panner.process(buffer);
		}
	}

	inline function addInsert(insert: DSP): DSP {
		assert(Critical, !insert.inUse, "DSP objects can only belong to one unique channel");
		insert.inUse = true;
		inserts.push(insert);
		return insert;
	}

	inline function removeInsert(insert: DSP) {
		var found = inserts.remove(insert);
		if (found) {
			insert.inUse = false;
		}
	}

	function synchronize() {
		var message: Null<Message>;
		while ((message = messages.tryPop()) != null) {
			parseMessage(message);
		}

		for (insert in inserts) {
			insert.synchronize();
		}

		if (panner != null) {
			panner.synchronize();
		}
	}

	function parseMessage(message: Message) {
		switch (message.id) {
			case ChannelMessageID.Play: play(cast message.data);
			case ChannelMessageID.Pause: pause();
			case ChannelMessageID.Stop: stop();

			case ChannelMessageID.PVolume: pVolume.targetValue = cast message.data;
			case ChannelMessageID.PDopplerRatio: pDopplerRatio.targetValue = cast message.data;
			case ChannelMessageID.PDstAttenuation: pDstAttenuation.targetValue = cast message.data;

			default:
		}
	}

	inline function sendMessage(message: Message) {
		messages.add(message);
	}
}

enum abstract AttenuationMode(Int) {
	var Linear;
	var Inverse;
	var Exponential;
}
