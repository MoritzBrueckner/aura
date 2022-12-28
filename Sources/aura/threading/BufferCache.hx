// =============================================================================
// getBuffer() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
//
// References:
// [1]: https://github.com/Kode/Kha/blob/3a3e9e6d51b1d6e3309a80cd795860da3ea07355/Backends/Kinc-hxcpp/main.cpp#L186-L233
//
// =============================================================================

package aura.threading;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

import aura.types.AudioBuffer;
import aura.types.ComplexArray;
import aura.utils.Pointer;

class BufferCache {

	// TODO: Make max tree height configurable
	public static inline var MAX_TREE_HEIGHT = 8;

	/**
		Number of audioCallback() invocations since the last allocation. This is
		used to automatically switch off interactions with the garbage collector
		in the audio thread if there are no allocations for some time (for extra
		performance).
	**/
	static var lastAllocationTimer: Int = 0;

	/**
		Each level in the channel tree has its own buffer that can be shared by
		the channels on that level.
	**/
	static var treeBuffers: Vector<Pointer<AudioBuffer>>;

	static var bufferConfigs: Vector<BufferConfig>;

	public static inline function init() {
		treeBuffers = new Vector(MAX_TREE_HEIGHT);
		for (i in 0...treeBuffers.length) {
			treeBuffers[i] = new Pointer<AudioBuffer>();
		}

		bufferConfigs = BufferType.createAllConfigs();
	}

	public static inline function updateTimer() {
		lastAllocationTimer++;
		if (lastAllocationTimer > 100) {
			kha.audio2.Audio.disableGcInteractions = true;
		}
	}

	public static function getTreeBuffer(treeLevel: Int, numChannels: Int, channelLength: Int): Null<AudioBuffer> {
		var p_buffer = treeBuffers[treeLevel];

		if (!getBuffer(TAudioBuffer, p_buffer, numChannels, channelLength)) {
			// Unexpected allocation message is already printed
			trace('  treeLevel: $treeLevel');
			return null;
		}

		return p_buffer.get();
	}

	@:generic
	public static function getBuffer<T>(bufferType: BufferType, p_buffer: PointerType<T>, numChannels: Int, channelLength: Int): Bool {
		final bufferCfg = bufferConfigs[bufferType];

		var buffer = p_buffer.get();
		final currentNumChannels = (buffer == null) ? 0 : bufferCfg.getNumChannels(buffer);
		final currentChannelLength = (buffer == null) ? 0 : bufferCfg.getChannelLength(buffer);

		if (buffer != null && currentNumChannels >= numChannels && currentChannelLength >= channelLength) {
			// Buffer is already big enough
			return true;
		}

		if (kha.audio2.Audio.disableGcInteractions) {
			// This code is executed in the case that there are suddenly
			// more samples requested while the GC interactions are turned
			// off (because the number of samples was sufficient for a
			// longer time). We can't just turn on GC interactions, it will
			// not take effect before the next audio callback invocation, so
			// we skip this "frame" instead (see [1] for reference).

			trace("Unexpected allocation request in audio thread.");
			final haveMsgNumC = (buffer == null) ? 'no buffer' : '${currentNumChannels}';
			final haveMsgen = (buffer == null) ? 'no buffer' : '${currentChannelLength}';
			trace('  wanted amount of channels: $numChannels (have: $haveMsgNumC)');
			trace('  wanted channel length: $channelLength (have: $haveMsgen)');

			lastAllocationTimer = 0;
			kha.audio2.Audio.disableGcInteractions = false;
			return false;
		}

		// If the buffer exists but too few samples fit in, overallocate by
		// factor 2 to avoid too many allocations. Eventually the buffer will be
		// big enough for the required amount of samples. If the buffer does not
		// exist yet, do not overallocate to prevent too high memory usage
		// (the requested length should not change much).
		buffer = cast bufferCfg.construct(numChannels, buffer == null ? channelLength : channelLength * 2);
		p_buffer.set(buffer);
		lastAllocationTimer = 0;
		return true;
	}
}

@:structInit
class BufferConfig {
	public var construct: Int->Int->Any;
	public var getNumChannels: Any->Int;
	public var getChannelLength: Any->Int;
}

/**
	Type-unsafe workaround for covariance and unification issues when working
	with the generic `BufferCache.getBuffer()`.
**/
enum abstract BufferType(Int) to Int {
	/** Represents `aura.types.AudioBuffer`. **/
	var TAudioBuffer;
	/** Represents `kha.arrays.Float32Array`. **/
	var TFloat32Array;
	/** Represents `Array<Float>`. **/
	var TArrayFloat;
	/** Represents `Array<dsp.Complex>`. **/
	var TArrayComplex;

	private var enumSize;

	public static function createAllConfigs(): Vector<BufferConfig> {
		final out = new Vector<BufferConfig>(enumSize);
		out[TAudioBuffer] = ({
			construct: (numChannels: Int, channelLength: Int) -> {
				return new AudioBuffer(numChannels, channelLength);
			},
			getNumChannels: (buffer: Any) -> {
				return (cast buffer: AudioBuffer).numChannels;
			},
			getChannelLength: (buffer: Any) -> {
				return (cast buffer: AudioBuffer).channelLength;
			}
		}: BufferConfig);
		out[TFloat32Array] = ({
			construct: (numChannels: Int, channelLength: Int) -> {
				return new Float32Array(channelLength);
			},
			getNumChannels: (buffer: Any) -> {
				return 1;
			},
			getChannelLength: (buffer: Any) -> {
				return (cast buffer: Float32Array).length;
			}
		}: BufferConfig);
		out[TArrayFloat] = ({
			construct: (numChannels: Int, channelLength: Int) -> {
				final v = new Array<Float>();
				v.resize(channelLength);
				return v;
			},
			getNumChannels: (buffer: Any) -> {
				return 1;
			},
			getChannelLength: (buffer: Any) -> {
				return (cast buffer: Array<Float>).length;
			}
		}: BufferConfig);
		out[TArrayComplex] = ({
			construct: (numChannels: Int, channelLength: Int) -> {
				return new ComplexArray(channelLength);
			},
			getNumChannels: (buffer: Any) -> {
				return 1;
			},
			getChannelLength: (buffer: Any) -> {
				return (cast buffer: ComplexArray).length;
			}
		}: BufferConfig);
		return out;
	}
}
