package aura.utils;

#if (cpp && AURA_WITH_OPTICK)
@:cppInclude('optick.h')
#end
class Profiler {
	public static inline function frame(threadName: String) {
		#if (cpp && AURA_WITH_OPTICK)
			untyped __cpp__("OPTICK_FRAME({0})", threadName);
		#end
	}

	public static inline function event() {
		#if (cpp && AURA_WITH_OPTICK)
			untyped __cpp__("OPTICK_EVENT()");
		#end
	}

	public static inline function shutdown() {
		#if (cpp && AURA_WITH_OPTICK)
			untyped __cpp__("OPTICK_SHUTDOWN()");
		#end
	}
}
