package aura;

import kha.Scheduler;

import aura.threading.BufferCache;

class Time {
	public static var lastTime(default, null): Float = 0.0;
	public static var delta(default, null): Float = 0.0;

	public static function update() {
		delta = Scheduler.realTime() - lastTime;
		lastTime = Scheduler.realTime();

		BufferCache.updateTimer();
	}
}
