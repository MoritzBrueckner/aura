package auratests.dsp;

import utest.Assert;

import aura.Aura;
import aura.dsp.FractionalDelayLine;
import aura.types.AudioBuffer;
import aura.utils.TestSignals;

@:access(aura.dsp.FractionalDelayLine)
class TestFractionalDelayLine extends utest.Test {
	var audioBuffer: AudioBuffer;
	var delayLine: FractionalDelayLine;

	function setup() {
		audioBuffer = new AudioBuffer(2, 8);
		delayLine = new FractionalDelayLine(2, 8);
	}

	function test_zeroDelayTime_noDelay() {
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(0));
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(1));

		delayLine.at_setDelayLength(Left, 0.0);
		delayLine.at_setDelayLength(Right, 0.0);

		delayLine.process(audioBuffer);

		Assert.floatEquals(1.0, audioBuffer.getChannelView(0)[0]);
		Assert.floatEquals(0.0, audioBuffer.getChannelView(0)[1]);

		Assert.floatEquals(1.0, audioBuffer.getChannelView(1)[0]);
		Assert.floatEquals(0.0, audioBuffer.getChannelView(1)[1]);
	}

	function test_integralDelayTime_independentChannels() {
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(0));
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(1));

		delayLine.at_setDelayLength(Left, 1.0);
		delayLine.at_setDelayLength(Right, 3.0);

		delayLine.process(audioBuffer);

		Assert.floatEquals(0.0, audioBuffer.getChannelView(0)[0]);
		Assert.floatEquals(1.0, audioBuffer.getChannelView(0)[1]);

		Assert.floatEquals(0.0, audioBuffer.getChannelView(1)[0]);
		Assert.floatEquals(1.0, audioBuffer.getChannelView(1)[3]);
	}

	function test_floatDelayTime_independentChannels() {
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(0));
		TestSignals.fillUnitImpulse(audioBuffer.getChannelView(1));

		delayLine.at_setDelayLength(Left, 0.8);
		delayLine.at_setDelayLength(Right, 3.4);

		delayLine.process(audioBuffer);

		Assert.floatEquals(0.2, audioBuffer.getChannelView(0)[0]);
		Assert.floatEquals(0.8, audioBuffer.getChannelView(0)[1]);

		Assert.floatEquals(0.6, audioBuffer.getChannelView(1)[3]);
		Assert.floatEquals(0.4, audioBuffer.getChannelView(1)[4]);
	}
}
