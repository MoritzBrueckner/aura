package aura.threading;

@:struct
@:structInit
class ChannelMessage {
	public final id: ChannelMessageID;
	public final data: Any;
}

enum abstract ChannelMessageID(Int) {
	final Play;
	final Pause;
	final Stop;

	// Parameters
	final PVolume;
	final PPitch;
	final PDopplerRatio;
	final PDstAttenuation;
}

@:struct
@:structInit
class DSPMessage {
	public final id: Int;
	public final data: Any;
}

enum abstract DSPMessageID(Int) from Int to Int {
	final BypassEnable;
	final BypassDisable;

	final SwapBufferReady;

	final SetDelays;

	final _SubtypeOffset;
}
