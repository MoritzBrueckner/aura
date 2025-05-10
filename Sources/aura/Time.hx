package aura;

import kha.Scheduler;

import aura.threading.BufferCache;

class Time {
	public static var lastTime(default, null): Float = 0.0;
	public static var delta(default, null): Float = 0.0;

	#if AURA_UNIT_TESTS
		public static var overrideTime: Null<Float> = null;
	#end

	#if AURA_BENCHMARK
		public static var times: Array<Float>;
		static var benchmarkStarted = false;
		static var currentIteration = 0;
		static var numIterations = 0;
		static var onBenchmarkDone: Array<Float>->Void;
	#end

	public static inline function getTime():Float {
		#if AURA_UNIT_TESTS
			if (overrideTime != null) {
				return overrideTime;
			}
		#end
		return Scheduler.time();
	}

	public static inline function update() {
		delta = getTime() - lastTime;
		lastTime = getTime();

		BufferCache.updateTimer();
	}

	#if AURA_BENCHMARK
		public static inline function endOfFrame() {
			if (benchmarkStarted) {
				times[currentIteration] = Scheduler.time() - lastTime;
				currentIteration++;
				if (currentIteration == numIterations) {
					onBenchmarkDone(times);
					benchmarkStarted = false;
					currentIteration = 0;
				}
			}
		}

		public static function startBenchmark(numIterations: Int, onBenchmarkDone: Array<Float>->Void) {
			Time.numIterations = numIterations;
			Time.onBenchmarkDone = onBenchmarkDone;
			times = new Array();
			times.resize(numIterations);

			benchmarkStarted = true;
		}
	#end
}
