package aura.threading;

/**
	Non-blocking first in/first out queue for thread synchronization. On targets
	with threading support, `sys.thread.Dequeue` is used, on those without
	threading `haxe.ds.List` is used instead.
**/
@:generic
@:forward(add)
abstract Fifo<T>(FifoImpl<T>) {
	public inline function new() {
		this = new FifoImpl<T>();
	}

	public inline function tryPop(): Null<T> {
		return this.pop(false);
	}
}

#if (target.threaded)
	private typedef FifoImpl<T> = sys.thread.Deque<T>;
#else
	@:generic
	@:forward(add)
	private abstract FifoImpl<T>(List<T>) {
		public inline function new() {
			this = new List<T>();
		}

		public inline function pop(block: Bool): Null<T> {
			return this.pop();
		}
	}
#end
