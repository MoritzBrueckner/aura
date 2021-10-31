package aura.threading;

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
	final PBalance;
	final PPitch;
	final PDopplerRatio;
	final PDstAttenuation;
}

@:structInit
class DSPMessage {
	public final id: DSPMessageID;
	public final data: Any;
}

enum abstract DSPMessageID(Int) {
	final BypassEnable;
	final BypassDisable;

	final SwapBufferReady;
}
