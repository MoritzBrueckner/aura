package aura;

class Assert {
	// TODO: Set this via compile flag
	static var assertLevel: AssertLevel = Critical;

	public static macro function assert(condition: ExprOf<Bool>, level: AssertLevel = Error): ExprOf<Void> {
		if (level == Hidden || level < assertLevel) {
			return macro {};
		}

		return macro {
			if (!$condition) {
				throw 'Failed assertion: ${$v{condition.toString()}}';
			}
		};
	}

}



enum abstract AssertLevel(Int) from Int to Int{
	var Hidden;
	var Debug;
	var Warning;
	var Error;
	var Critical;

	@:op(A < B) static function lt(a:AssertLevel, b:AssertLevel):Bool;
	@:op(A > B) static function gt(a:AssertLevel, b:AssertLevel):Bool;
}
