package aura;

import kha.Scheduler;

import aura.threading.BufferCache;

class Time {
	public static var lastTime(default, null): Float = 0.0;
	public static var delta(default, null): Float = 0.0;

	#if AURA_BENCHMARK
		public static var times: Array<Float>;
		static var benchmarkStarted = false;
		static var currentIteration = 0;
		static var numIterations = 0;
		static var onBenchmarkDone: Array<Float>->Void;
	#end

	public static inline function update() {
		delta = Scheduler.realTime() - lastTime;
		lastTime = Scheduler.realTime();

		BufferCache.updateTimer();
	}

	#if AURA_BENCHMARK
		public static inline function endOfFrame() {
			if (benchmarkStarted) {
				times[currentIteration] = Scheduler.realTime() - lastTime;
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
