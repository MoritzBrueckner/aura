package aura.utils;

/**
    The decibel (dB) is a logarithmic unit used to express the ratio of two values of a physical quantity.
    One of these values is often a standard reference value, in which case the decibel is used to express the level[a] of the other value relative to this reference.

    The number of decibels is ten times the logarithm to base 10 of the ratio of two power quantities.

	A change in power by a factor of 10 corresponds to a 10 dB change in level.
	At the half power point an audio circuit or an antenna exhibits an attenuation of approximately 3 dB.
	A change in amplitude by a factor of 10 results in a change in power by a factor of 100, which corresponds to a 20 dB change in level.
	A change in amplitude ratio by a factor of 2 (equivalently factor of 4 in power change) approximately corresponds to a 6 dB change in level.
**/
class Decibel {

	public static inline function toDecibel( volume : Float ) : Float {
		return 20 * Math.log10( volume );
	}

	public static inline function toLinear( db : Float ) : Float {
		return Math.pow( 10, db / 20 );
	}

}

