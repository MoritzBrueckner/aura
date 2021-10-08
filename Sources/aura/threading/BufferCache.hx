// =============================================================================
// getBuffer() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
// =============================================================================

package aura.threading;

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

	public static inline function init() {
		treeBuffers = new Vector(MAX_TREE_HEIGHT);
		for (i in 0...treeBuffers.length) {
			treeBuffers[i] = new Pointer<Float32Array>();
		}
	}

	public static inline function updateTimer() {
		lastAllocationTimer++;
		if (lastAllocationTimer > 100) {
			kha.audio2.Audio.disableGcInteractions = true;
		}
	}

	public static function getTreeBuffer(treeLevel: Int, length: Int): Null<Float32Array> {
		var p_buffer = treeBuffers[treeLevel];
		getBuffer(p_buffer, length);

		var buffer = p_buffer.get();
		if (buffer == null) {
			// Unexpected allocation message is already printed
			trace('  treeLevel: $treeLevel');
			return null;
		}

		p_buffer.set(buffer);
		return buffer;
	}

	public static function getBuffer(p_buffer: Pointer<Float32Array>, length: Int) {
		var buffer = p_buffer.get();
		if (buffer != null && buffer.length >= length) {
			// Buffer is already big enough
			return;
		}

		if (kha.audio2.Audio.disableGcInteractions) {
			// This code is executed in the case that there are suddenly
			// more samples requested while the GC interactions are turned
			// off (because the number of samples was sufficient for a
			// longer time). We can't just turn on GC interactions, it will
			// not take effect before the next audio callback invocation, so
			// we skip this "frame" instead (see [1] for reference).

			trace("Unexpected allocation request in audio thread.");
			final haveMsg = (buffer == null) ? 'no buffer' : '${buffer.length}';
			trace('  wanted length: $length (have: $haveMsg)');

			lastAllocationTimer = 0;
			kha.audio2.Audio.disableGcInteractions = false;
			p_buffer.set(null);
			return;
		}

		// If the buffer exists but is too small, overallocate by factor 2
		// to avoid too many allocations, eventually the buffer will be big
		// enough for the required amount of samples. If the buffer does not
		// exist yet, do not overallocate to prevent too high memory usage
		// (the requested length should not change much).
		buffer = new Float32Array(buffer == null ? length : length * 2);
		p_buffer.set(buffer);
		lastAllocationTimer = 0;
	}
}
