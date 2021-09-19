package aura.utils;

/**
	Merges the contents of `from` into `to` and returns the latter (`to` is
	modified).
**/
@:generic
inline function mergeIntoThis<K, V>(to: Map<K, V>, from: Map<K, V>): Map<K, V> {
	for (key => val in from) {
		to[key] = val;
	}
	return to;
}
