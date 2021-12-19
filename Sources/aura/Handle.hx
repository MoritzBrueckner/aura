package aura;

import aura.channels.BaseChannel;
import aura.dsp.DSP;
import aura.dsp.panner.Panner;
import aura.utils.MathUtils;

/**
	Main-thread handle to an audio channel in the audio thread.
**/
@:access(aura.channels.BaseChannel)
@:allow(aura.dsp.panner.Panner)
class Handle {
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

	public var panner(default, null): Null<Panner> = null;

	/**
		Link to the audio channel in the audio thread.
	**/
	final channel: BaseChannel;

	// Parameter cache for getter functions
	var _volume: Float = 1.0;
	var _balance: Balance = Balance.CENTER;
	var _pitch: Float = 1.0;

	public inline function new(channel: BaseChannel) {
		this.channel = channel;
	}

	/**
		Starts the playback. If the sound wasn't played before or was stopped,
		the playback starts from the beginning. If it is paused, playback starts
		from the position where it was paused.
	**/
	public inline function play() {
		channel.sendMessage({ id: Play, data: null });
	}

	public inline function pause() {
		channel.sendMessage({ id: Pause, data: null });
	}

	public inline function stop() {
		channel.sendMessage({ id: Stop, data: null });
	}

	public inline function addInsert(insert: DSP): DSP {
		return channel.addInsert(insert);
	}

	public inline function removeInsert(insert: DSP) {
		channel.removeInsert(insert);
	}

	public inline function setVolume(volume: Float) {
		channel.sendMessage({ id: PVolume, data: maxF(0.0, volume) });
		this._volume = volume;
	}

	public inline function getVolume(): Float {
		return this._volume;
	}

	public inline function setBalance(balance: Balance) {
		channel.sendMessage({ id: PBalance, data: balance });
		this._balance = balance;
	}

	public inline function getBalance(): Balance {
		return this._balance;
	}

	public inline function setPitch(pitch: Float) {
		channel.sendMessage({ id: PPitch, data: maxF(0.0, pitch) });
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
