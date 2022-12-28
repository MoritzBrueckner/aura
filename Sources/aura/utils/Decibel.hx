package aura.utils;

/**
	The decibel (dB) is a relative unit of measurement equal to one tenth of a bel (B).
	It expresses the ratio of two values of a power or root-power quantity on a logarithmic scale.

	The number of decibels is ten times the logarithm to base 10 of the ratio of two power quantities.

	A change in power by a factor of 10 corresponds to a 10 dB change in level.
	At the half power point an audio circuit or an antenna exhibits an attenuation of approximately 3 dB.
	A change in amplitude by a factor of 10 results in a change in power by a factor of 100, which corresponds to a 20 dB change in level.
	A change in amplitude ratio by a factor of 2 (equivalently factor of 4 in power change) approximately corresponds to a 6 dB change in level.
**/
class Decibel {
	@:pure public static inline function toDecibel(volume: Float): Float {
		return 20 * MathUtils.log10(volume);
	}

	@:pure public static inline function toLinear(db: Float): Float {
		return Math.pow(10, db / 20);
	}
}
