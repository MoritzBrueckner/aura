package aura.utils;

import haxe.macro.Context;
import haxe.macro.PositionTools;
import haxe.PosInfos;
import haxe.exceptions.PosException;
import haxe.macro.Expr;

using haxe.macro.ExprTools;

class Assert {
	/**
		Every assert statement with a level below this threshold is ignored.
		This variable can be set via the compiler flag `AURA_ASSERT_LEVEL`.
	**/
	static var assertThreshold = AssertLevel.Critical;

	public static macro function assert(levelExpr: ExprOf<AssertLevel>, condition: ExprOf<Bool>): Expr {
		final level: AssertLevel = AssertLevel.fromExpr(levelExpr);
		final assertThreshold = AssertLevel.fromString(Context.definedValue("AURA_ASSERT_LEVEL"));

		if (level < assertThreshold) {
			return macro {};
		}

		return macro {
			if (!$condition) {
				#if AURA_ASSERT_QUIT kha.System.stop(); #end

				@:pos(condition.pos)
				@:privateAccess throwAssertionError($v{condition.toString()});
			}
		};
	}

	/**
		Helper function to prevent Haxe "bug" that actually throws an error
		even when using `macro throw` (inlining this method also does not work).
	**/
	static function throwAssertionError(exprString: String, ?pos: PosInfos) {
		throw new PosException('\n[Aura] Failed assertion: \n|\t$exprString\n|  ', pos);
	}
}

enum abstract AssertLevel(Int) from Int to Int {
	var Hidden: AssertLevel = 0;
	var Debug: AssertLevel = 1;
	var Warning: AssertLevel = 2;
	var Error: AssertLevel = 3;
	var Critical: AssertLevel = 4;

	@:op(A < B) static function lt(a:AssertLevel, b:AssertLevel):Bool;
	@:op(A > B) static function gt(a:AssertLevel, b:AssertLevel):Bool;

	public static function fromExpr(e: ExprOf<AssertLevel>): AssertLevel {
		switch (e.expr) {
			case EConst(CIdent(v)): return fromString(v);
			default: throw 'Unsupported expression: $e';
		};
	}

	public static function fromString(s: String): AssertLevel {
		return switch (s) {
			case "Hidden": Hidden;
			case "Debug": Debug;
			case "Warning": Warning;
			case "Error": Error;
			case "Critical" | null: Critical;
			default: throw 'Could not convert string to AssertLevel: $s';
		}
	}
}
