// =============================================================================
// getBuffer() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
// =============================================================================

package aura.threading;

import aura.types.Complex.ComplexArray;
import haxe.ds.Vector;

import kha.arrays.Float32Array;

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
	static var treeBuffers: Vector<Pointer<Float32Array>>;

	static var bufferConfigs: Map<BufferType, BufferConfig>;

	public static inline function init() {
		treeBuffers = new Vector(MAX_TREE_HEIGHT);
		for (i in 0...treeBuffers.length) {
			treeBuffers[i] = new Pointer<Float32Array>();
		}

		bufferConfigs = BufferType.createAllConfigs();
	}

	public static inline function updateTimer() {
		lastAllocationTimer++;
		if (lastAllocationTimer > 100) {
			kha.audio2.Audio.disableGcInteractions = true;
		}
	}

	public static function getTreeBuffer(treeLevel: Int, length: Int): Null<Float32Array> {
		var p_buffer = treeBuffers[treeLevel];

		if (!getBuffer(TFloat32Array, p_buffer, length)) {
			// Unexpected allocation message is already printed
			trace('  treeLevel: $treeLevel');
			return null;
		}

		return p_buffer.get();
	}

	@:generic
	public static function getBuffer<T>(bufferType: BufferType, p_buffer: PointerType<T>, length: Int): Bool {
		final bufferCfg = bufferConfigs.get(bufferType);

		var buffer = p_buffer.get();

		if (buffer != null && bufferCfg.getLength(buffer) >= length) {
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
			final haveMsg = (buffer == null) ? 'no buffer' : '${bufferCfg.getLength(buffer)}';
			trace('  wanted length: $length (have: $haveMsg)');

			lastAllocationTimer = 0;
			kha.audio2.Audio.disableGcInteractions = false;
			return false;
		}

		// If the buffer exists but is too small, overallocate by factor 2
		// to avoid too many allocations, eventually the buffer will be big
		// enough for the required amount of samples. If the buffer does not
		// exist yet, do not overallocate to prevent too high memory usage
		// (the requested length should not change much).
		buffer = cast bufferCfg.construct(buffer == null ? length : length * 2);
		p_buffer.set(buffer);
		lastAllocationTimer = 0;
		return true;
	}
}

class BufferConfig {
	public var construct: Int->Any;
	public var getLength: Any->Int;

	public function new(construct: Int->Any, getLength: Any->Int) {
		this.construct = construct;
		this.getLength = getLength;
	}
}

/**
	Type-unsafe workaround for covariance and unification issues when working
	with the generic `BufferCache.getBuffer()`.
**/
enum abstract BufferType(Int) {
	/** Represents `kha.arrays.Float32Array`. **/
	var TFloat32Array;
	/** Represents `Array<Float>`. **/
	var TArrayFloat;
	/** Represents `Array<dsp.Complex>`. **/
	var TArrayComplex;

	public static function createAllConfigs(): Map<BufferType, BufferConfig> {
		final out = new Map<BufferType, BufferConfig>();
		out[TFloat32Array] = new BufferConfig(
			(length: Int) -> {
				return new Float32Array(length);
			},
			(buffer: Any) -> {
				return cast (buffer: Float32Array).length;
			}
		);
		out[TArrayFloat] = new BufferConfig(
			(length: Int) -> {
				final v = new Array<Float>();
				v.resize(length);
				return v;
			},
			(buffer: Any) -> {
				return cast (buffer: Array<Float>).length;
			}
		);
		out[TArrayComplex] = new BufferConfig(
			(length: Int) -> {
				return new ComplexArray(length);
			},
			(buffer: Any) -> {
				return cast (buffer: ComplexArray).length;
			}
		);
		return out;
	}
}
