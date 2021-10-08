package aura.utils;

@:generic
class Pointer<T> {
	public var value: Null<T>;

	public inline function new(value: Null<T> = null) {
		set(value);
	}

	public inline function set(value: Null<T>) {
		this.value = value;
	}

	public inline function get(): Null<T> {
		return this.value;
	}
}
