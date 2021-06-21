package aura;

import kha.arrays.Float32Array;

import aura.MathUtils;

abstract class AudioChannel {
	/**
		The sound's volume relative to the volume of the sound file.
	**/
	public var volume: Float = 1.0;

	var treeLevel: Int = 0;

	var paused: Bool = false;

	public abstract function nextSamples(requestedSamples: Float32Array, requestedLength: Int, sampleRate: Hertz): Void;

	public abstract function play(): Void;
	public abstract function pause(): Void;
	public abstract function stop(): Void;
}
