package aura.channels.generators;

abstract class BaseGenerator extends BaseChannel {
	public function play(retrigger: Bool): Void {
		paused.store(false);
		finished.store(false);
	}

	public function pause(): Void {
		paused.store(true);
	}

	public function stop(): Void {
		finished.store(true);
	}
}
