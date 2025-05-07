package aura.threading;

@:struct
@:structInit
class Message {
	public final id: Int;
	public final data: Null<Dynamic>;

	public final inline function dataAsArrayUnsafe(): Null<Array<Dynamic>> {
		return data;
	}
}

@:autoBuild(aura.utils.macro.ExtensibleEnumBuilder.build())
@:build(aura.utils.macro.ExtensibleEnumBuilder.build())
class MessageID {}

class ChannelMessageID extends MessageID {
	final Play;
	final Pause;
	final Stop;

	// Parameters
	final PVolume;
	final PPitch;
	final PDopplerRatio;
	final PDstAttenuation;

	#if (kha_html5 || kha_debug_html5)
	final PVolumeLeft;
	final PVolumeRight;
	#end
}

class DSPMessageID extends MessageID {
	final BypassEnable;
	final BypassDisable;

	final SwapBufferReady;

	final SetDelays;
}
