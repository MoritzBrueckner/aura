package aura.utils.macro;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassType;

/**
	This macro implements integer enum types that can extend from others, at the
	cost of some limitations.

	## Usage
	```haxe
	@:autoBuild(aura.utils.macro.ExtensibleEnumBuilder.build())
	@:build(aura.utils.macro.ExtensibleEnumBuilder.build())
	class BaseEnum {
		var ABaseEnumValue;
	}

	class ExtendingEnum extends BaseEnum {
		var AnExtendingEnumValue;
	}
	```

	This macro transforms the variables in above example into the static inline
	variables `BaseEnum.ABaseEnumValue = 0` and `ExtendingEnum.AnExtendingEnumValue = 1`.

	The compiler dump after the macro looks as follows:

	```haxe
	// BaseEnum.dump
	@:used @:autoBuild(aura.utils.macro.ExtensibleEnumBuilder.build()) @:build(aura.utils.macro.ExtensibleEnumBuilder.build())
	class BaseEnum {

		@:value(0)
		public static inline var ABaseEnumValue:Int = 0;

		@:value(ABaseEnumValue + 1)
		static inline var _SubtypeOffset:Int = 1;
	}

	// ExtendingEnum.dump
	@:used @:build(aura.utils.macro.ExtensibleEnumBuilder.build()) @:autoBuild(aura.utils.macro.ExtensibleEnumBuilder.build())
	class ExtendingEnum extends BaseEnum {

		@:value(@:privateAccess Main.BaseEnum._SubtypeOffset)
		public static inline var AnExtendingEnumValue:Int = 1;

		@:value(AnExtendingEnumValue + 1)
		static inline var _SubtypeOffset:Int = 2;
	}
	```

	## Limitations
	- Only integer types are supported.
	- The enums are stored in classes instead of `enum abstract` types.
	- Actual values are typed as int, no auto-completion and less intelligent switch/case statements.
	- No actual OOP-like inheritance (which wouldn't work with enums since enum inheritance would need to be contravariant).
	  More importantly, only the values of the variables are extended, but subclassing enums _don't inherit the variables_
	  of their superclass enums.
	- Little complexity and compile time added by using a macro.
**/
class ExtensibleEnumBuilder {
	static var SUBTYPE_VARNAME = "_SubtypeOffset";

	public static macro function build(): Array<Field> {
		final fields = Context.getBuildFields();
		final newFields = new Array<Field>();

		final cls = Context.getLocalClass().get();
		final superClass = cls.superClass;
		final isExtending = superClass != null;

		var lastField: Null<Field> = null;
		for (field in fields) {
			switch (field.kind) {
				case FVar(complexType, expr):

					var newExpr: Expr;
					if (lastField == null) {
						if (isExtending) {
							final path = classTypeToStringPath(superClass.t.get());
							newExpr = macro @:pos(Context.currentPos()) @:privateAccess ${strPathToExpr(path)}.$SUBTYPE_VARNAME;
						}
						else {
							newExpr = macro 0;
						}
					}
					else {
						newExpr = macro $i{lastField.name} + 1;
					}

					newFields.push({
						name: field.name,
						access: [APublic, AStatic, AInline],
						kind: FVar(complexType, newExpr),
						meta: field.meta,
						doc: field.doc,
						pos: Context.currentPos()
					});

					lastField = field;

				default:
					newFields.push(field);
			}
		}

		newFields.push({
			name: SUBTYPE_VARNAME,
			access: [APrivate, AStatic, AInline],
			kind: FVar(macro: Int, lastField != null ? macro $i{lastField.name} + 1 : macro 0),
			pos: Context.currentPos()
		});

		return newFields;
	}

	static function classTypeToStringPath(classType: ClassType): String {
		var moduleName = classType.module.split(".").pop();

		final name = moduleName + "." + classType.name;
		return classType.pack.length == 0 ? name : classType.pack.join(".") + "." + name;
	}

	static function strPathToExpr(path: String): Expr {
		// final pathArray = path.split(".");
		// final first = EConst(CIdent(pathArray.shift()));
		// var expr = { expr: first, pos: Context.currentPos() };

		// for (item in pathArray) {
		// 	expr = { expr: EField(expr, item), pos: Context.currentPos() };
		// }
		// return expr;
		return macro $p{path.split(".")}
	}
}
