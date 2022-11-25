package auratests.channels;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Types.Balance;
import aura.channels.ResamplingAudioChannel;
import aura.types.AudioBuffer;

@:access(aura.channels.ResamplingAudioChannel)
class TestResamplingAudioChannel extends utest.Test {
	static inline var channelLength = 16;

	var audioChannel: ResamplingAudioChannel;

	final rampLeft = new Array<Float>();
	final rampRight = new Array<Float>();
	final data = new Float32Array(2 * channelLength); // interleaved stereo

	function setupClass() {
		rampLeft.resize(channelLength);
		rampRight.resize(channelLength);

		for (i in 0...channelLength) { // Fill data with a value ramp
			final val = (i + 1) / channelLength;

			data[i * 2 + 0] = rampLeft[i] = val;
			data[i * 2 + 1] = rampRight[i] = -val;
		}
	}

	function setup() {
		audioChannel = new ResamplingAudioChannel(data, false, 1000);
	}

	function teardown() {}

	function test_dataConversion() {
		for (i in 0...channelLength) {
			Assert.floatEquals(rampLeft[i], audioChannel.data.getChannelView(0)[i]);
			Assert.floatEquals(rampRight[i], audioChannel.data.getChannelView(1)[i]);
		}
	}

	function test_sampleFloatPos_SamplesExactValuesAtDiscretePositions() {
		final channelLeft = 0;
		final channelRight = 1;

		Assert.floatEquals(rampLeft[0], audioChannel.sampleFloatPos(0.0, channelLeft, 1000));
		Assert.floatEquals(rampLeft[1], audioChannel.sampleFloatPos(1.0, channelLeft, 1000));

		Assert.floatEquals(rampRight[0], audioChannel.sampleFloatPos(0.0, channelRight, 1000));
		Assert.floatEquals(rampRight[1], audioChannel.sampleFloatPos(1.0, channelRight, 1000));
	}

	function test_sampleFloatPos_InterpolatesLinearlyBetweenDiscreteSamples() {
		final channelLeft = 0;
		final channelRight = 1;

		Assert.floatEquals((rampLeft[0] + rampLeft[1]) * 0.5, audioChannel.sampleFloatPos(0.5, channelLeft, 1000));
		Assert.floatEquals(rampLeft[0] * 0.7 + rampLeft[1] * 0.3, audioChannel.sampleFloatPos(0.3, channelLeft, 1000));

		Assert.floatEquals((rampRight[0] + rampRight[1]) * 0.5, audioChannel.sampleFloatPos(0.5, channelRight, 1000));
		Assert.floatEquals(rampRight[0] * 0.7 + rampRight[1] * 0.3, audioChannel.sampleFloatPos(0.3, channelRight, 1000));
	}

	function test_sampleFloatPos_AssertsSamplePositionNotNegative() {
		#if (AURA_ASSERT_LEVEL!="NoAssertions")
		Assert.raises(() -> {
			audioChannel.sampleFloatPos(-1.0, 0, 1000);
		});
		#else
		Assert.pass();
		#end
	}

	function test_sampleFloatPos_ClampsValuesOutOfUpperDataBounds() {
		final channelLeft = 0;
		final channelRight = 1;

		Assert.floatEquals(rampLeft[channelLength - 1], audioChannel.sampleFloatPos(channelLength - 0.5, channelLeft, 1000));
		Assert.floatEquals(rampLeft[channelLength - 1], audioChannel.sampleFloatPos(channelLength, channelLeft, 1000));

		Assert.floatEquals(rampRight[channelLength - 1], audioChannel.sampleFloatPos(channelLength - 0.5, channelRight, 1000));
		Assert.floatEquals(rampRight[channelLength - 1], audioChannel.sampleFloatPos(channelLength, channelRight, 1000));
	}

	@:depends(test_dataConversion)
	function test_sampleFloatPos() {
		// #if (AURA_ASSERT_LEVEL!="NoAssertions")
		// Assert.raises(() -> {
		// 	audioChannel.sampleFloatPos(-1.0, 0, 1000);
		// });
		// #end

		// // Left channel
		// Assert.floatEquals(rampLeft[0], audioChannel.sampleFloatPos(0.0, 0, 1000));
		// Assert.floatEquals(rampLeft[1], audioChannel.sampleFloatPos(1.0, 0, 1000));
		// Assert.floatEquals((rampLeft[0] + rampLeft[1]) * 0.5, audioChannel.sampleFloatPos(0.5, 0, 1000));
		// Assert.floatEquals(rampLeft[0] * 0.7 + rampLeft[1] * 0.3, audioChannel.sampleFloatPos(0.3, 0, 1000));
		// Assert.floatEquals(rampLeft[channelLength - 1], audioChannel.sampleFloatPos(channelLength, 0, 1000));

		// // Right channel
		// Assert.floatEquals(rampRight[0], audioChannel.sampleFloatPos(0.0, 1, 1000));
		// Assert.floatEquals(rampRight[1], audioChannel.sampleFloatPos(1.0, 1, 1000));
		// Assert.floatEquals((rampRight[0] + rampRight[1]) * 0.5, audioChannel.sampleFloatPos(0.5, 1, 1000));
		// Assert.floatEquals(rampRight[0] * 0.7 + rampRight[1] * 0.3, audioChannel.sampleFloatPos(0.3, 1, 1000));
		// Assert.floatEquals(rampRight[channelLength - 1], audioChannel.sampleFloatPos(channelLength, 1, 1000));

		// Check different sample rates
		Assert.floatEquals(rampLeft[0], audioChannel.sampleFloatPos(0.0, 0, 500));
		Assert.floatEquals(rampLeft[1], audioChannel.sampleFloatPos(0.5, 0, 500));
		Assert.floatEquals(rampLeft[2], audioChannel.sampleFloatPos(1.0, 0, 500));
		Assert.floatEquals(rampLeft[channelLength - 1], audioChannel.sampleFloatPos(channelLength / 2, 0, 500));

		Assert.floatEquals(rampRight[0], audioChannel.sampleFloatPos(0.0, 1, 500));
		Assert.floatEquals(rampRight[1], audioChannel.sampleFloatPos(0.5, 1, 500));
		Assert.floatEquals(rampRight[2], audioChannel.sampleFloatPos(1.0, 1, 500));
		Assert.floatEquals(rampRight[channelLength - 1], audioChannel.sampleFloatPos(channelLength / 2, 1, 500));

		Assert.floatEquals(rampLeft[0], audioChannel.sampleFloatPos(0.0, 0, 2000));
		Assert.floatEquals((rampLeft[0] + rampLeft[1]) * 0.5, audioChannel.sampleFloatPos(1.0, 0, 2000));

		Assert.floatEquals(rampRight[0], audioChannel.sampleFloatPos(0.0, 1, 2000));
		Assert.floatEquals((rampRight[0] + rampRight[1]) * 0.5, audioChannel.sampleFloatPos(1.0, 1, 2000));
	}

	function test_getResampledLength() {
		Assert.equals(8, audioChannel.getResampleLength(500));
		Assert.equals(32, audioChannel.getResampleLength(2000));
	}

	@:depends(test_sampleFloatPos)
	@:depends(test_getResampledLength)
	function test_nextSamples() {
		final outBuffer = new AudioBuffer(2, channelLength);

		audioChannel.nextSamples(outBuffer, 1000);

		for (i in 0...channelLength) {
			Assert.floatEquals(rampLeft[i], outBuffer.getChannelView(0)[i]);
			Assert.floatEquals(rampRight[i], outBuffer.getChannelView(1)[i]);
		}

		// Now the channel has processed all data and will reset position to 0
		Assert.equals(0, audioChannel.playbackPosition);
		Assert.floatEquals(0.0, audioChannel.floatPosition);

		// No looping, but request more samples
		final longOutBuffer = new AudioBuffer(2, channelLength + 4);
		audioChannel.nextSamples(longOutBuffer, 1000);
		for (i in 0...channelLength) {
			Assert.floatEquals(rampLeft[i], longOutBuffer.getChannelView(0)[i]);
			Assert.floatEquals(rampRight[i], longOutBuffer.getChannelView(1)[i]);
		}
		for (i in channelLength...channelLength + 4) {
			Assert.floatEquals(0.0, longOutBuffer.getChannelView(0)[i]);
			Assert.floatEquals(0.0, longOutBuffer.getChannelView(1)[i]);
		}

		// Now change the sample rate, second half should be zero
		audioChannel.playbackPosition = 0;
		audioChannel.floatPosition = 0.0;
		audioChannel.nextSamples(outBuffer, 500);
		for (i in Std.int(channelLength / 2)...channelLength) {
			Assert.floatEquals(0.0, outBuffer.getChannelView(0)[i]);
			Assert.floatEquals(0.0, outBuffer.getChannelView(1)[i]);
		}

		// Now with looping
		audioChannel.playbackPosition = 0;
		audioChannel.floatPosition = 0.0;
		audioChannel.looping = true;
		audioChannel.nextSamples(outBuffer, 500);
		final halfChannelLength = Std.int(channelLength / 2);
		for (i in 0...halfChannelLength) {
			Assert.floatEquals(outBuffer.getChannelView(0)[i], outBuffer.getChannelView(0)[halfChannelLength + i], null, '$i');
			Assert.floatEquals(outBuffer.getChannelView(1)[i], outBuffer.getChannelView(1)[halfChannelLength + i], null, '$i');
		}

		// TODO: check sample precise looping without gaps with unusual sample rates?
	}
}
