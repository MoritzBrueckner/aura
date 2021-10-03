// =============================================================================
// getTreeBuffer() is roughly based on
// https://github.com/Kode/Kha/blob/master/Sources/kha/audio2/Audio1.hx
//
// =============================================================================

package aura.threading;

import haxe.ds.Vector;

import kha.arrays.Float32Array;

class BufferCache {

	/**
		Number of audioCallback() invocations since the last allocation. This is
		used to automatically switch off interactions with the garbage collector
		in the audio thread if there are no allocations for some time (for extra
		performance).
	**/
	static var lastAllocationTimer: Int = 0;

	static var treeBuffers: Vector<Float32Array>;

	public static function init() {
		// TODO: Make max tree height configurable
		treeBuffers = new Vector(8);
	}

	public static function getTreeBuffer(treeLevel: Int, length: Int): Null<Float32Array> {
		var cache = treeBuffers[treeLevel];

		if (cache == null || cache.length < length) {
			if (kha.audio2.Audio.disableGcInteractions) {
				// This code is executed in the case that there are suddenly
				// more samples requested while the GC interactions are turned
				// off (because the number of samples was sufficient for a
				// longer time). We can't just turn on GC interactions, it will
				// not take effect before the next audio callback invocation, so
				// we skip this "frame" instead (see [1] for reference).

				trace("Unexpected allocation request in audio thread.");
				final haveMsg = (cache == null) ? 'no cache' : '${cache.length}';
				trace('  treeLevel: $treeLevel, wanted length: $length (have: $haveMsg)');

				lastAllocationTimer = 0;
				kha.audio2.Audio.disableGcInteractions = false;
				return null;
			}

			// If the cache exists but is too small, overallocate by factor 2 to
			// avoid too many allocations, eventually the cache will be big
			// enough for the required amount of samples. If the cache does not
			// exist yet, do not overallocate to prevent too high memory usage
			// (the requested length should not change much).
			treeBuffers[treeLevel] = cache = new Float32Array(cache == null ? length : length * 2);
			lastAllocationTimer = 0;
		}
		else if (treeLevel == 0) {
			if (lastAllocationTimer > 100) {
				kha.audio2.Audio.disableGcInteractions = true;
			}
			else {
				lastAllocationTimer += 1;
			}
		}

		return cache;
	}
}
