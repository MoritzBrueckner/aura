package aura.channels.generators;

abstract class BaseGenerator extends BaseChannel {
	public function play(retrigger: Bool): Void {
		paused = false;
		finished = false;
	}

	public function pause(): Void {
		paused = true;
	}

	public function stop(): Void {
		finished = true;
	}
}
