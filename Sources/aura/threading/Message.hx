package aura.threading;

@:structInit
class Message {
	public final id: MessageID;
	public final data: Any;
}

enum abstract MessageID(Int) {
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
