package auratests.dsp;

import utest.Assert;

import kha.arrays.Float32Array;

import aura.Aura;
import aura.dsp.FFTConvolver;
import aura.types.AudioBuffer;
import aura.types.Complex;
import aura.utils.MathUtils;
import aura.utils.TestSignals;

@:access(aura.dsp.FFTConvolver)
class TestFFTConvolver extends utest.Test {
	var audioBuffer: AudioBuffer;
	var fftConvolver: FFTConvolver;

	function setup() {
		audioBuffer = new AudioBuffer(2, FFTConvolver.FFT_SIZE);
		fftConvolver = new FFTConvolver();
	}

	function test_process_noFadeIfTemporalInterpLengthIsZero() {
		fftConvolver.temporalInterpolationLength = 0;

		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
		}

		setImpulseFreqsToConstant(new Complex(1.0, 0.0));
		fftConvolver.process(audioBuffer);
		discardOverlapForNextProcess();
		for (i in 0...FFTConvolver.FFT_SIZE) {
			Assert.floatEquals(Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), audioBuffer.getChannelView(1)[i]);
		}

		setImpulseFreqsToConstant(new Complex(0.0, 0.0));
		fftConvolver.process(audioBuffer);
		for (i in 0...FFTConvolver.FFT_SIZE) {
			Assert.floatEquals(0, audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(0, audioBuffer.getChannelView(1)[i]);
		}
	}

	function test_process_crossfadeIfTemporalInterpLengthIsLargerZero() {
		fftConvolver.temporalInterpolationLength = 20;

		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
		}
		setImpulseFreqsToConstant(new Complex(1.0, 0.0));
		fftConvolver.process(audioBuffer);
		discardOverlapForNextProcess();
		for (i in 0...FFTConvolver.FFT_SIZE) {
			final t = minF(i, fftConvolver.temporalInterpolationLength) / fftConvolver.temporalInterpolationLength;
			Assert.floatEquals(lerp(0.0, Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), t), audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(lerp(0.0, Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), t), audioBuffer.getChannelView(1)[i]);
		}

		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 8 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.sin(i * 8 * Math.PI / audioBuffer.channelLength);
		}
		setImpulseFreqsToConstant(new Complex(0.0, 0.0));
		fftConvolver.process(audioBuffer);
		for (i in 0...FFTConvolver.FFT_SIZE) {
			final t = minF(i, fftConvolver.temporalInterpolationLength) / fftConvolver.temporalInterpolationLength;
			Assert.floatEquals(lerp(Math.sin(i * 8 * Math.PI / audioBuffer.channelLength), 0.0, t), audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(lerp(Math.sin(i * 8 * Math.PI / audioBuffer.channelLength), 0.0, t), audioBuffer.getChannelView(1)[i]);
		}
	}

	function test_process_crossfadeEntireChunkSize() {
		fftConvolver.temporalInterpolationLength = -1;

		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.sin(i * 4 * Math.PI / audioBuffer.channelLength);
		}
		setImpulseFreqsToConstant(new Complex(1.0, 0.0));
		fftConvolver.process(audioBuffer);
		discardOverlapForNextProcess();
		for (i in 0...FFTConvolver.FFT_SIZE) {
			final t = minF(i, FFTConvolver.CHUNK_SIZE) / FFTConvolver.CHUNK_SIZE;
			Assert.floatEquals(lerp(0.0, Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), t), audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(lerp(0.0, Math.sin(i * 4 * Math.PI / audioBuffer.channelLength), t), audioBuffer.getChannelView(1)[i]);
		}

		for (i in 0...audioBuffer.channelLength) {
			audioBuffer.getChannelView(0)[i] = Math.sin(i * 8 * Math.PI / audioBuffer.channelLength);
			audioBuffer.getChannelView(1)[i] = Math.sin(i * 8 * Math.PI / audioBuffer.channelLength);
		}
		setImpulseFreqsToConstant(new Complex(0.0, 0.0));
		fftConvolver.process(audioBuffer);
		for (i in 0...FFTConvolver.FFT_SIZE) {
			final t = minF(i, FFTConvolver.CHUNK_SIZE) / FFTConvolver.CHUNK_SIZE;
			Assert.floatEquals(lerp(Math.sin(i * 8 * Math.PI / audioBuffer.channelLength), 0.0, t), audioBuffer.getChannelView(0)[i]);
			Assert.floatEquals(lerp(Math.sin(i * 8 * Math.PI / audioBuffer.channelLength), 0.0, t), audioBuffer.getChannelView(1)[i]);
		}
	}

	function setImpulseFreqsToConstant(value: Complex) {
		for (i in 0...FFTConvolver.FFT_SIZE) {
			fftConvolver.impulseFFT.getOutput(0 + fftConvolver.currentImpulseAlternationIndex)[i] = value;
			fftConvolver.impulseFFT.getOutput(2 + fftConvolver.currentImpulseAlternationIndex)[i] = value;
		}
		fftConvolver.currentImpulseAlternationIndex = 1 - fftConvolver.currentImpulseAlternationIndex;

		fftConvolver.overlapLength[0] = FFTConvolver.CHUNK_SIZE;
		fftConvolver.overlapLength[1] = FFTConvolver.CHUNK_SIZE;
		fftConvolver.prevImpulseLengths[0] = FFTConvolver.CHUNK_SIZE;
		fftConvolver.prevImpulseLengths[1] = FFTConvolver.CHUNK_SIZE;
	}

	function discardOverlapForNextProcess() {
		for (c in 0...FFTConvolver.NUM_CHANNELS) {
			for (i in 0...fftConvolver.overlapPrev[c].length) {
				fftConvolver.overlapPrev[c][i] = 0.0;
			}
		}
	}
}
