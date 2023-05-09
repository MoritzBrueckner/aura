package aura.dsp.sourcefx;

import aura.types.AudioBuffer;
import aura.Types;

/**
	A special type of audio effect that—unlike insert effects—is not applied
	continuously during audio playback but instead to the audio source buffer of
	an `aura.channels.UncompBufferChannel` object.

	This allows `SourceEffect`s to bake effects or provide sound variations
	(for example by selecting random sounds from a pool of sounds, or by creating
	sound variations on the fly with `aura.dsp.sourcefx.VelvetNoiseVariator`).
**/
abstract class SourceEffect {
	/**
		If `false` (default), `SourceEffect.process()` is only called
		before the linked audio channel is played for the very first time with
		its current combination of source effects. Adding or removing source
		effects to a channel results in a recalculation of all source effects
		on that channel.

		If `true`, _additionally_ call `SourceEffect.process()` before each
		consecutive replay of the audio source, including:
		- Repetitions if the audio source is looping
		- Calls to `audioChannel.play()` if the audio channel was stopped or
		    `play()` is called with `retrigger` set to `true`.
	**/
	public var applyOnReplay(default, null): AtomicBool = new AtomicBool(false);

	/**
		`SourceEffect`s are allowed to change the length of the source
		audio passed as `srcBuffer` to `SourceEffect.process()`.

		This function is used to calculate the amount of memory that needs to be
		allocated to efficiently process all audio source effects of a channel.
		It must return the least required channel length of the effect's
		destination buffer with respect to the given source channel length.
	**/
	abstract function calculateRequiredChannelLength(srcChannelLength: Int): Int;

	/**
		Apply the effect to the audio data stored in the given source buffer and
		write the result into the destination buffer.

		- `srcBuffer` and `dstBuffer` may or may not point to the same object.

		- The channels of `srcBuffer` might be longer than the valid audio
		  contained, use `srcChannelLength` to get the amount of valid samples
		  in each channel of the source buffer.

		- `dstBuffer` is guaranteed to contain channels  _at least_ the length
		  of `calculateRequiredChannelLength(srcChannelLength)`, it is expected
		  that the source effect fills `dstBuffer` exactly to that length.

		This function must return the required destination channel length as
		calculated by `calculateRequiredChannelLength(srcChannelLength)`.
	**/
	abstract function process(srcBuffer: AudioBuffer, srcChannelLength: Int, dstBuffer: AudioBuffer): Int;
}
