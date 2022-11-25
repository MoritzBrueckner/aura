package aura.utils;

import haxe.Exception;
import haxe.PosInfos;
import haxe.exceptions.PosException;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

class Assert {
	/**
		Checks whether the given expression evaluates to true. If this is not
		the case, a `AuraAssertionException` with additional information is
		thrown.

		The assert level describes the severity of the assertion. If the
		severity is lower than the level stored in the `AURA_ASSERT_LEVEL` flag,
		the assertion is omitted from the code so that it doesn't decrease the
		runtime performance.

		@param level The severity of this assertion.
		@param condition The conditional expression to test.
		@param message Optional message to display when the assertion fails.
	**/
	public static macro function assert(level: ExprOf<AssertLevel>, condition: ExprOf<Bool>, ?message: ExprOf<String>): Expr {
		final levelVal: AssertLevel = AssertLevel.fromExpr(level);
		final assertThreshold = AssertLevel.fromString(Context.definedValue("AURA_ASSERT_LEVEL"));

		if (levelVal < assertThreshold) {
			return macro {};
		}

		return macro {
			if (!$condition) {
				#if AURA_ASSERT_QUIT kha.System.stop(); #end

				@:pos(condition.pos)
				@:privateAccess aura.utils.Assert.throwAssertionError($v{condition.toString()}, ${message});
			}
		};
	}

	/**
		Helper function to prevent Haxe "bug" that actually throws an error
		even when using `macro throw` (inlining this method also does not work).
	**/
	static function throwAssertionError(exprString: String, message: Null<String>, ?pos: PosInfos) {
		throw new AuraAssertionException(exprString, message, pos);
	}
}

/**
	Exception that is thrown when an assertion fails.

	@see `Assert`
**/
class AuraAssertionException extends PosException {

	/**
		@param exprString The string representation of the failed assert condition.
		@param message Custom error message, use `null` to omit this.
	**/
	public function new(exprString: String, message: Null<String>, ?previous: Exception, ?pos: Null<PosInfos>) {
		final optMsg = message != "" ? '\n\tMessage: $message' : "";

		super('\n[Aura] Failed assertion:$optMsg\n\tExpression: ($exprString)', previous, pos);
	}
}

enum abstract AssertLevel(Int) from Int to Int {
	var Debug: AssertLevel;
	var Warning: AssertLevel;
	var Error: AssertLevel;
	var Critical: AssertLevel;

	// Don't use this level in assert() calls!
	var NoAssertions: AssertLevel;

	public static function fromExpr(e: ExprOf<AssertLevel>): AssertLevel {
		switch (e.expr) {
			case EConst(CIdent(v)): return fromString(v);
			default: throw new Exception('Unsupported expression: $e');
		};
	}

	/**
		Converts a string into an `AssertLevel`, the string must be spelled
		exactly as the assert level. `null` defaults to `AssertLevel.Critical`.
	**/
	public static function fromString(s: String): AssertLevel {
		return switch (s) {
			case "Debug": Debug;
			case "Warning": Warning;
			case "Error": Error;
			case "Critical" | null: Critical;
			case "NoAssertions": NoAssertions;
			default: throw 'Could not convert "$s" to AssertLevel';
		}
	}

	@:op(A < B) static function lt(a:AssertLevel, b:AssertLevel):Bool;
	@:op(A > B) static function gt(a:AssertLevel, b:AssertLevel):Bool;
}
